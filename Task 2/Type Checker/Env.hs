module Env where

import AbsCPP
import PrintCPP
import ErrM

import qualified Data.Map.Strict as Map

-- Pueden hacer uso de las funciones de Map

-- Definición de un Environment
type Env = (Sig,[Context])
type Sig = Map.Map Id ([Type],Type)
type Context = Map.Map Id Type


lookupVar :: Env -> Id -> Err Type
lookupVar (_, [])  x = fail ("la variable "++ show x ++ "no esta definida")
lookupVar (s, c:cs) x = case Map.lookup x c of
    Nothing -> lookupVar (s, cs) x
    Just t -> return t

lookupFun :: Env -> Id -> Err ([Type], Type)
lookupFun (s, _) f = case Map.lookup f s of
    Nothing -> fail ("la funcion "++ show f ++" no esta definida")
    Just p -> return p

updateVar :: Env -> Id -> Type -> Err Env
updateVar (_, []) _ _ = fail "no hay ningun contexto que pueda actualizar"
updateVar (s, c:cs) x t = case Map.lookup x c of
    Nothing -> return (s, Map.insert x t c:cs)
    Just _ -> fail ("no se puede redeclarar la variable "++ show x)

updateFun :: Env -> Id -> ([Type],Type) -> Err Env
updateFun (s, cs) f p = case Map.lookup f s of
    Nothing -> return (Map.insert f p s, cs)
    Just _ -> fail ("no se puede redeclarar la funcion "++ show f)  

newBlock :: Env -> Env
newBlock (s, cs) = (s, ([Map.empty]++cs))

emptyEnv :: Env
emptyEnv = (Map.empty, [Map.empty])
