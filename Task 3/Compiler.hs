module Compiler where
-- Santiago Toscanini (232566) - Sofia Tejerina (209239)

-- java virtual machine instructions reference
-- http://cs.au.dk/~mis/dOvs/jvmspec/ref-Java.html

import AbsCPP
import TypeChecker

import qualified Data.Map as Map
import Control.Monad
import Control.Monad.Trans.State.Lazy
--import Control.Monad.State

type Instruction = String
type FunType     = String
type Label       = Int

data Env = Env {
  funs      :: Map.Map Id FunType,
  vars      :: [Map.Map Id Int],    -- Stack of variables blocks !
  maxvars   :: [Int],               -- Stack of counter for variable addresses in each block
  maxstk    :: Int,                 -- counter for maximal stack depth
  labels    :: Int,                 -- counter for jump labels
  code      :: [Instruction] 
}

emptyEnv :: Env
emptyEnv = Env { funs=Map.empty,
                 vars=[],
                 maxvars=[0],
                 maxstk=0,
                 labels=0,
                 code=[]}

emit :: Instruction -> State Env () -- recibe una instruccion y devuelve el enviroment modificado, agrega a "code" la nueva instruccion
emit i = do
  env <- get -- automaticamente obtiene el enviroment
  put (env { code = i : code env }) -- modifica o actualiza el enviroment

typeSize :: Type -> Int
typeSize Type_double = 2
typeSize _           = 1

extendVar :: Type -> Id -> State Env () --recibe una variable y un tipo y le asigna la proxima direccion de memoria libre a esa variable, deja pronta cual va a ser la proxima direccion de memoria libre (modifica vars de enviroment)
extendVar t i = do
  env <- get
  put (env { vars = Map.insert i (head (maxvars env)) (head (vars env)) : tail (vars env)
           , maxvars = head (maxvars env) + typeSize t : tail (maxvars env)
           }
      )

extendVars :: Type -> [Id] -> State Env () -- llama al metodo extendVar
extendVars t ids = mapM_ (extendVar t) ids

typeJVM :: Type -> String
typeJVM Type_int    = "I"
typeJVM Type_double = "D"
typeJVM Type_void   = "V"
typeJVM Type_bool   = "Z"
typeJVM Type_string = "Ljava/lang/String;"

funJVMType :: String -> [Type] -> Type -> FunType
funJVMType i typs rty = i ++ "(" ++ (foldr (\ t s -> typeJVM t ++ s) "" typs) ++ ")" ++ typeJVM rty

funJVM :: String -> String -> [Type] -> Type -> FunType
funJVM i clas argty rty = "invokestatic " ++ clas ++"/" ++ funJVMType i argty rty

extendFunEnv :: Id -> FunType -> State Env () -- recibimos una funcion y la guardamos
extendFunEnv f t = do
  env <- get
  put (env {funs = Map.insert f t (funs env)})

extendDef :: String -> Def -> State Env ()
extendDef cls (DFun t (Id f) args _) = extendFunEnv (Id f) (funJVM f cls (map aux args) t)
  where
    aux (ADecl t _) = t

-- Besides added in type checker
extendBuiltinDefs :: State Env ()
extendBuiltinDefs = mapM_ ( \ ((Id i),(argTys,rty)) -> extendFunEnv (Id i) $ funJVM i "Runtime" argTys rty) buildInFunctions

newBlock :: State Env () -- agrega un bloque al tope del map y repetir el valor maximo de la lista
newBlock = do
  env <- get
  put (env {vars = Map.empty : vars env
           , maxvars = head (maxvars env) : maxvars env
           }
      )

exitBlock :: State Env () -- quitar del tope del stack
exitBlock = do
  env <- get
  put (env { vars = tail (vars env)
           , maxvars = tail (maxvars env)
           }
      )

newLabel :: State Env String
newLabel  = do
  env <- get
  put (env { labels = labels env + 1 })
  return ("label" ++ show (labels env))

lookupFun :: Id -> State Env FunType -- obtenemos el fun type a partir del nombre de una funcion
lookupFun f = do
  env <- get
  return ((funs env) Map.! f)

lookupVars :: Id -> [Map.Map Id Int] -> Int
lookupVars x [] = error "error que no puede pasar"
lookupVars x (m:ms) = case Map.lookup x m of
                        Nothing -> lookupVars x ms
                        Just d -> d

lookupVar :: Id -> State Env Int -- obtenemos el lugar de memoria a partir del nombre de la variable
lookupVar i = do
  env <- get
  return (lookupVars i (vars env))

-- Entry point from ccpp.
-- Arguments: cls is the class name and p is the typed embedded abstract syntax tree (returned by the type checker).
-- Hints: call compileP and run the State monad !
compile :: String -> Program -> [Instruction]
compile cls p = reverse ( code (execState (compileP cls p) emptyEnv) )

compileP :: String -> Program -> State Env () 
compileP cls (PDefs defs) = do
  emit $ ".class public " ++ cls
  emit $ ".super java/lang/Object"
  emit $ ""
  emit $ ".method public <init>()V"
  emit $ "  aload_0"
  emit $ "  invokenonvirtual java/lang/Object/<init>()V"
  emit $ "  return"
  emit $ ".end method"
  emit $ ""
  extendBuiltinDefs
  mapM  (extendDef cls) defs
  mapM_ compileDef defs

compileDef :: Def -> State Env ()
compileDef (DFun t (Id i) args stmts) = do
  newBlock 
  if i == "main" then do
       emit $ ".method public static main([Ljava/lang/String;)V"
       extendVar Type_string (Id "args") -- in fact is an array of strings ([Ljava/lang/String;)
  else emit $ ".method public static " ++ (funJVMType i (map (\ (ADecl t _) -> t) args) t)
  emit $ ".limit locals 1000"  -- aca se puede ser mas precisoo !
  emit $ ".limit stack  1000"  -- aca se puede ser mas precisoo !
  mapM (\ (ADecl t i) -> extendVar t i) args
  mapM compileStm stmts
  exitBlock
  emit $ "return"
  emit $ ".end method"
  emit ""

compileStm :: Stm -> State Env ()
compileStm (SExp e@(ETyped _ t)) = do -- utilizamos e@ para crear el alias
  compileExp e
  if t `elem` [Type_int, Type_bool, Type_string] --Los statements no nos pueden modificar el stack, y al compilar la expresion dejamos un valor en el tope del stack que tenemos que quitar 
    then emit "pop"
    else if t == Type_double
      then emit "pop2"
      else return ()
compileStm (SDecls t ids) = extendVars t ids
compileStm (SInit t id exp) = do
  extendVar t id
  compileExp exp
  x <- lookupVar id
  if t `elem` [Type_int, Type_bool]
    then do
      emit ("istore " ++ show x)
    else if t == Type_double
      then do
        emit ("dstore " ++ show x)
      else -- si es tipo string
        do
          emit("astore " ++ show x)
compileStm (SReturn (ETyped exp t)) = do
  compileExp (ETyped exp t)
  if t == Type_string
    then emit "areturn"
  else if t == Type_double
    then emit "dreturn"
  else emit "ireturn"
compileStm SReturnVoid = emit "return"
compileStm (SWhile exp stm) = do
  test <- newLabel
  end <- newLabel
  emit (test ++ ":")
  compileExp exp
  emit("ifeq " ++ end)
  compileStm stm
  emit ("goto " ++ test)
  emit (end ++ ":")
compileStm (SBlock stms) = do
  newBlock
  mapM_ compileStm stms
  exitBlock
compileStm (SIfElse e s1 s2) = do
  t <- newLabel
  f <- newLabel
  compileExp e
  emit ("ifeq " ++ f)
  compileStm s1
  emit ("goto " ++ t)
  emit (f ++ ":")
  compileStm s2
  emit (t ++ ":")
compileStm stm = error "statement indefinido"

compileExp :: Exp -> State Env ()
compileExp (ETyped ETrue _) = emit "bipush 1"
compileExp (ETyped EFalse _) = emit "bipush 0"
compileExp (ETyped (EInt n) _) = emit ("ldc " ++ show n)
compileExp (ETyped (EDouble d) _) = emit ("ldc2_w " ++ show d)
compileExp (ETyped (EString s) _) = emit ("ldc " ++ s)
compileExp (ETyped (EId x) t) = do
  dir <- lookupVar x
  if t `elem` [Type_int, Type_bool]
    then emit ("iload " ++ show dir)
    else if t == Type_double
      then emit ("dload " ++ show dir)
      else if t == Type_string
        then emit ("aload " ++ show dir)
        else error "no tendria que llegar aca"
compileExp (ETyped (EApp f exps) t) = do
  mapM_ compileExp exps
  invf <- lookupFun f
  emit invf
compileExp (ETyped (EPIncr id) t) = do
  x <- lookupVar id
  emit ("iload " ++ show x)
  emit "dup"
  emit "iconst_1"
  emit "iadd"
  emit ("istore " ++ show x)
compileExp (ETyped (EPDecr id) t) = do
  x <- lookupVar id
  emit ("iload " ++ show x)
  emit "iconst_1"
  if t == Type_int 
  then do
    emit "isub"
    emit "dup"
  else
    do
      emit "dsub"
      emit "dup2"
  emit ("istore " ++ show x)
compileExp (ETyped (EIncr id) t) = do
  x <- lookupVar id
  emit ("iload " ++ show x)
  emit "iconst_1"
  if t == Type_int 
    then do
      emit "iadd"
      emit "dup"
    else
      do
        emit "dadd"
        emit "dup2"
  emit ("istore " ++ show x)
compileExp (ETyped (EDecr id) t) = do
  x <- lookupVar id
  emit ("iload " ++ show x)
  emit "iconst_1"
  if t == Type_int 
    then do
      emit "isub"
      emit "dup"
    else
      do
        emit "dsub"
        emit "dup2"
  emit ("istore " ++ show x)
compileExp (ETyped (ETimes exp1 exp2) t) = do
  compileExp exp1
  compileExp exp2
  if t == Type_int
    then emit "imul"
    else emit "dmul"
compileExp (ETyped (EDiv exp1 exp2) t) = do
  compileExp exp1
  compileExp exp2
  if t == Type_int
    then emit "idiv"
    else emit "ddiv"
compileExp (ETyped (EPlus exp1 exp2) t) = do
  compileExp exp1
  compileExp exp2
  if t == Type_int
    then emit "iadd"
    else if t == Type_double
      then emit "dadd"
      else
        do
          inv <- lookupFun (Id "concatStr")
          emit inv
compileExp (ETyped (EMinus exp1 exp2) t) = do
  compileExp exp1
  compileExp exp2
  if t == Type_int
    then emit "isub"
  else
    emit "dsub"
compileExp (ETyped (ELt e1@(ETyped _ Type_int) e2) Type_bool) = compileExpCmp e1 e2 Lt
compileExp (ETyped (ELt e1@(ETyped _ Type_double) e2) Type_bool) = compileExpCmpDouble e1 e2 Lt
compileExp (ETyped (EGt e1@(ETyped _ Type_int) e2) Type_bool) = compileExpCmp e1 e2 Gt
compileExp (ETyped (EGt e1@(ETyped _ Type_double) e2) Type_bool) = compileExpCmpDouble e1 e2 Gt
compileExp (ETyped (ELtEq e1@(ETyped _ Type_int) e2) Type_bool) = compileExpCmp e1 e2 Le
compileExp (ETyped (ELtEq e1@(ETyped _ Type_double) e2) Type_bool) = compileExpCmpDouble e1 e2 Le
compileExp (ETyped (EGtEq e1@(ETyped _ Type_int) e2) Type_bool) = compileExpCmp e1 e2 Ge
compileExp (ETyped (EGtEq e1@(ETyped _ Type_double) e2) Type_bool) = compileExpCmpDouble e1 e2 Ge
compileExp (ETyped (EEq e1@(ETyped _ Type_int) e2) Type_bool) = compileExpCmp e1 e2 Equal
compileExp (ETyped (EEq e1@(ETyped _ Type_double) e2) Type_bool) = compileExpCmpDouble e1 e2 Equal
compileExp (ETyped (ENEq e1@(ETyped _ Type_int) e2) Type_bool) = compileExpCmp e1 e2 NEqual
compileExp (ETyped (ENEq e1@(ETyped _ Type_double) e2) Type_bool) = compileExpCmpDouble e1 e2 NEqual
compileExp (ETyped (EAnd exp1 exp2) _) = do
  compileExp exp1
  emit "bipush 1"
  true <- newLabel
  true2 <- newLabel
  end <- newLabel
  emit ("if_icmpeq " ++ true)
  emit "bipush 0"
  emit ("goto " ++ end)
  emit (true ++ ":")
  compileExp exp2
  emit "bipush 1"
  emit ("if_icmpeq " ++ true2)
  emit "bipush 0"
  emit ("goto " ++ end)
  emit (true2 ++ ":")
  emit "bipush 1"
  emit (end ++ ":")
compileExp (ETyped (EOr exp1 exp2) t) = do
  compileExp exp1
  emit "bipush 1"
  true <- newLabel
  true2 <- newLabel
  end <- newLabel
  emit ("if_icmpeq " ++ true)
  compileExp exp2
  emit "bipush 1"
  emit ("if_icmpeq " ++ true2)
  emit "bipush 0"
  emit ("goto " ++ end)
  emit ("goto " ++ end)
  emit (true ++ ":")
  emit (true2 ++ ":")
  emit "bipush 1"
  emit (end ++ ":")
compileExp (ETyped (EAss x e) t) = do
  compileExp e
  x <- lookupVar x
  if t `elem` [Type_int, Type_bool]
    then do
      emit "dup"
      emit ("istore " ++ show x)
    else if t == Type_double
      then do
        emit "dup2"
        emit ("dstore " ++ show x)
      else -- si es tipo string
        do
          emit "dup"
          emit("astore " ++ show x)
compileExp exp = error "exp indefinida"

compileExpCmp :: Exp -> Exp -> Cmp -> State Env ()
compileExpCmp e1 e2 cmp = do
  true <- newLabel
  emit "bipush 1"
  compileExp e1
  compileExp e2
  emit (show cmp ++ true)
  emit "pop"
  emit "bipush 0"
  emit (true ++ ":")

compileExpCmpDouble :: Exp -> Exp -> Cmp -> State Env ()
compileExpCmpDouble e1 e2 cmp = do
  true <- newLabel
  emit "bipush 1"
  compileExp e1
  compileExp e2
  emit "dcmpg"
  emit (showDbl cmp ++ true)
  emit "pop"
  emit "bipush 0"
  emit (true ++ ":")

-- Hints: usefull auxiliary functions for comparations compilation
data Cmp = Equal | NEqual | Lt | Gt | Ge | Le
  deriving (Eq)

instance Show Cmp where
  show Equal  = "if_icmpeq "
  show NEqual = "if_icmpne "
  show Lt     = "if_icmplt "
  show Gt     = "if_icmpgt "
  show Ge     = "if_icmpge "
  show Le     = "if_icmple "

showDbl :: Cmp -> Instruction
showDbl Equal  = "ifeq "
showDbl NEqual = "ifne "
showDbl Lt     = "iflt "
showDbl Gt     = "ifgt "
showDbl Ge     = "ifge "
showDbl Le     = "ifle "
