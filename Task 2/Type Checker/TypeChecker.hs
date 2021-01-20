module TypeChecker where

import AbsCPP
import PrintCPP
import ErrM
import Env

import Control.Monad

-- Método principal
typecheck :: Program -> Err ()
typecheck (PDefs defs) = do
    env' <- addFunctionsSignaturesToEnv emptyEnv defs
    checkDefs env' defs

-- Métodos secundarios
-- Pimera
addFunctionsSignaturesToEnv :: Env -> [Def] -> Err Env
addFunctionsSignaturesToEnv env [] = return env
addFunctionsSignaturesToEnv env (DFun typ f args stms:defs) = do
    haveRepeatedArgs args
    env' <- updateFun env f (map aux args,typ)
    addFunctionsSignaturesToEnv env' defs
    where
        aux :: Arg -> Type
        aux (ADecl typ _) = typ

haveRepeatedArgs :: [Arg] -> Err ()
haveRepeatedArgs [] = return ()
haveRepeatedArgs ((ADecl _ id):args) = do
    if (isIdAlreadyExistADecl id args)
        then fail "Los argumentos tienen nombres repetidos"
        else haveRepeatedArgs args

isIdAlreadyExistADecl :: Id -> [Arg] -> Bool
isIdAlreadyExistADecl id [] = False
isIdAlreadyExistADecl id ((ADecl _ i):xs) = case (id == i) of 
    {
        True -> True;
        False -> isIdAlreadyExistADecl id xs;
    }


-- segunda
checkDefs :: Env -> [Def] -> Err ()
checkDefs env defs = mapM_ (checkDef env) defs 

checkDef :: Env -> Def -> Err ()
checkDef env (DFun typ _ args stms) = do
    env' <- addArgumentsToEnv env args
    checkStms typ env' stms
    return ()

addArgumentsToEnv :: Env -> [Arg] -> Err Env
addArgumentsToEnv env [] = return env
addArgumentsToEnv env (ADecl typ x : args) = do 
    env' <- updateVar env x typ
    addArgumentsToEnv env' args


checkStms :: Type -> Env -> [Stm] -> Err Env
checkStms _ env [] = return env
checkStms typ env (stm:stms) = do
    env' <- checkStm typ env stm
    checkStms typ env' stms

checkStm :: Type -> Env -> Stm -> Err Env
checkStm _ env (SExp e) = do
    _ <- inferExp env e
    return env
checkStm t env (SDecls typ (i:is)) = do
    env' <- updateVar env i typ
    case (is) of
        {
            s:xs -> checkStm t env' (SDecls typ is);
            [] -> return env';
        }
checkStm _ env (SInit typ x e) = do
    checkExp env e typ
    updateVar env x typ
checkStm t env (SReturn e) = do
    typ <- inferExp env e
    if (t == typ)
        then return env
        else fail "El tipo de restorno no corresponde con el tipo de la funcion"
checkStm Type_void env SReturnVoid = do return env
checkStm _ _ SReturnVoid = do fail "No se puede devolver void porque la funcion no es de tipo void"
checkStm t env (SWhile e stm) = do
    etyp <- inferExp env e
    if (etyp == Type_bool)
        then checkStm t env stm
        else fail "La expresion dentro del While no es de tipo Boolean"
checkStm typ env (SBlock stms) = do
    checkStms typ (newBlock env) stms
    return env
checkStm t env (SIfElse e stm1 stm2) = do
    etyp <- inferExp env e
    if (etyp == Type_bool)
        then do
            checkStm t env (SBlock [stm1])
            checkStm t env (SBlock [stm2])
        else fail "La expresion evaluada no es de tipo Boolean"
checkStm _ _ _ = fail ("Statement no valido")


inferExp :: Env -> Exp -> Err Type
inferExp _ ETrue = return Type_bool
inferExp _ EFalse = return Type_bool

inferExp _ (EInt _ ) = return Type_int
inferExp _ (EDouble _ ) = return Type_double
inferExp _ (EString _) = return Type_string

inferExp env (EId x) = do
    t <- lookupVar env x
    return t

inferExp env (EApp f es) = do
    (ts, t) <- lookupFun env f
    inferExpAppAux env es ts
    return t

inferExp env (EPIncr e) = inferSimpleOp env e "incremento aplicado a arrgumento incorrecto"
inferExp env (EPDecr e) = inferSimpleOp env e "decremento aplicado a arrgumento incorrecto"
inferExp env (EIncr e) = inferSimpleOp env e "incremento aplicado a arrgumento incorrecto"
inferExp env (EDecr e) = inferSimpleOp env e "decremento aplicado a arrgumento incorrecto"

inferExp env (ETimes e1 e2) = inferBinOp env e1 e2 [Type_int, Type_double] "multiplicacion aplicada a argumentos incorrectos"
inferExp env (EDiv e1 e2) = inferBinOp env e1 e2 [Type_int, Type_double] "division aplicada a argumentos incorrectos"

inferExp env (EPlus e1 e2) = inferBinOp env e1 e2 [Type_int, Type_double, Type_string] "suma aplicada a argumentos incorrectos"
inferExp env (EMinus e1 e2) = inferBinOp env e1 e2 [Type_int, Type_double] "resta aplicada a argumentos incorrectos"

inferExp env (ELt e1 e2) = inferBoolBinOp env e1 e2 [Type_int, Type_double] "menor que aplicado a argumentos incorrectos"
inferExp env (EGt e1 e2) = inferBoolBinOp env e1 e2 [Type_int, Type_double] "mayor que aplicado a argumentos incorrectos"
inferExp env (ELtEq e1 e2) = inferBoolBinOp env e1 e2 [Type_int, Type_double] "menor o igual que aplicado a argumentos incorrectos"
inferExp env (EGtEq e1 e2) = inferBoolBinOp env e1 e2 [Type_int, Type_double] "mayor o igual que aplicado a argumentos incorrectos"

inferExp env (EEq e1 e2) = inferBoolBinOp env e1 e2 [Type_int, Type_double, Type_bool] "Igual que aplicado a argumentos incorrectos"
inferExp env (ENEq e1 e2) = inferBoolBinOp env e1 e2 [Type_int, Type_double, Type_bool] "Distinto que aplicado a argumentos incorrectos"

inferExp env (EAnd e1 e2) = inferBoolBinOp env e1 e2 [Type_bool] "And aplicado a argumentos incorrectos"
inferExp env (EOr e1 e2) = inferBoolBinOp env e1 e2 [Type_bool] "Or aplicado a argumento incorrectos"

inferExp env (EAss (EId x) e) = do
    t <- lookupVar env x
    checkExp env e t
    return t
inferExp _ (EAss _ _ ) = fail "Error quise asignar a una expresion no variable"

inferExp env (ETyped e1 typ) = fail "no se que es esto"


inferExpAppAux :: Env -> [Exp] -> [Type] -> Err ()
inferExpAppAux _ [] (_:_) = fail "la funcion la aplique con menos argumentos que los esperados"
inferExpAppAux _ (_:_) [] = fail "la funcion la aplique con mas argumentos que los esperados"
inferExpAppAux _ [] [] = return ()
inferExpAppAux env (e:es) (t:ts) = do
    checkExp env e t
    inferExpAppAux env es ts

inferSimpleOp :: Env -> Exp -> String -> Err Type
inferSimpleOp env e mess = do
    typ <- inferExp env e
    if typ `elem` [Type_int, Type_double]
        then do
            return typ
        else
            fail mess

inferBinOp :: Env -> Exp -> Exp -> [Type] -> String -> Err Type
inferBinOp env e1 e2 typs mess = do
    typ <- inferExp env e1
    if typ `elem` typs
        then do
            checkExp env e2 typ
            return typ
        else fail mess

inferBoolBinOp :: Env -> Exp -> Exp -> [Type] -> String -> Err Type
inferBoolBinOp env e1 e2 typs mess = do
    typ <- inferExp env e1
    if typ `elem` typs
        then do
            checkExp env e2 typ
            return Type_bool
        else fail mess




-- Pueden agregar más método y modificar firmas de los ya declarados

-- Infer Exp --



--Check exp --
checkExp :: Env -> Exp -> Type -> Err ()
checkExp env exp typ = do
    typ2 <- inferExp env exp
    if typ /= typ2
        then fail ("esperando type "++ show typ ++" pero obtuve "++ show typ2)
        else return ()

--check stms--


--check stm --





