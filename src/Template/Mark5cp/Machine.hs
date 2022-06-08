{-# LANGUAGE ImplicitParams #-}
{-# LANGUAGE NoFieldSelectors #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedRecordDot #-}
module Template.Mark5cp.Machine
    where

import Data.Bool
import Data.Char
import Data.List
import Data.List.Extra

import Language
import Heap
import Stack
import Iseq
import Utils

import Template.Mark5cp.State
import Template.Mark5cp.PPrint

import Debug.Trace qualified as Deb

debug :: Bool
debug = True

trace :: String -> a -> a
trace | debug     = Deb.trace
      | otherwise = const id 

traceShow :: Show a => a -> b -> b
traceShow | debug     = Deb.traceShow
          | otherwise = const id

{- * Mark 5 : Structured data -}
{- | Structure of the implementations -}

drive :: ([String] -> [String]) -> (String -> String)
drive f = unlines . f . ("" :) . lines

run :: (?sz :: Int, ?th :: Int) => String -> ([String] -> [String])
run prog inputs
    = showResults 
    $ eval
    $ setControl inputs
    $ compile 
    $ parse prog

setControl :: [String] -> TiState -> TiState
setControl ctrl state = state { control = ctrl }

{- | Compiler -}

compile :: (?sz :: Int, ?th :: Int) => CoreProgram -> TiState
compile prog = TiState
    { control = []
    , output  = []
    , stack   = initialStack1
    , dump    = initialDump
    , heap    = initialHeap1
    , globals = initialGlobals
    , stats   = initialStats
    , ruleid  = 0
    }
    where
        scDefs = prog ++ preludeDefs ++ extraPreludeDefs
        (initialHeap, initialGlobals) = buildInitialHeap scDefs
        initialStack = singletonStack addressOfMain
        initialStack1 = singletonStack addr
        addressOfMain = aLookup initialGlobals "main" (negate 1)
        (heap1, addr1)
            | addressOfMain < 0 = (initialHeap, aLookup initialGlobals "pmain" (error "no main and no pmain"))
            | otherwise         = case aLookup initialGlobals "Cons" (error "Cons is not defined") of
                addressOfCons    -> case aLookup initialGlobals "Nil" (error "Nil is not defined") of
                    addressOfNil   -> case hAlloc initialHeap (NAp addressOfCons addressOfMain) of
                        (h, a)       -> hAlloc h (NAp a addressOfNil)
        addressOfPrint = aLookup initialGlobals "printList" (error "printList is not defined")
        (initialHeap1, addr) = hAlloc heap1 (NAp addressOfPrint addr1)

extraPreludeDefs :: CoreProgram
extraPreludeDefs = 
    [ ("False", [], EConstr 0 0)
    , ("True" , [], EConstr 1 0)
    , ("not", ["x"], EAp (EAp (EAp (EVar "if") (EVar "x"))
                              (EVar "False"))
                         (EVar "True"))
    , ("and", ["x", "y"], EAp (EAp (EAp (EVar "if") (EVar "x"))
                                   (EVar "y"))
                              (EVar "False"))
    , ("or",  ["x", "y"], EAp (EAp (EAp (EVar "if") (EVar "x"))
                                   (EVar "True"))
                              (EVar "y"))
    , ("xor", ["x", "y"], EAp (EAp (EAp (EVar "if") (EVar "x"))
                                   (EAp (EVar "not") (EVar "y")))
                              (EVar "y"))
    , ("MkPair", [], EConstr 0 2)
    , ("fst", ["p"], EAp (EAp (EVar "casePair") (EVar "p"))
                         (EVar "K"))
    , ("snd", ["p"], EAp (EAp (EVar "casePair") (EVar "p"))
                         (EVar "K1"))
    , ("Nil", [], EConstr 0 0)
    , ("Cons", [], EConstr 1 2)
    , ("head", ["xs"], EAp (EAp (EAp (EVar "caseList") (EVar "xs"))
                                (EVar "abort"))
                           (EVar "K"))
    , ("tail", ["xs"], EAp (EAp (EAp (EVar "caseList") (EVar "xs"))
                                (EVar "abort"))
                           (EVar "K1"))
    , ("printList", ["xs"], EAp (EAp (EAp (EVar "caseList") (EVar "xs"))
                                     (EVar "stop"))
                                (EVar "printCons"))
    , ("printCons", ["h", "t"], EAp (EAp (EVar "print") (EVar "h"))
                                    (EAp (EVar "printList") (EVar "t")))
    ]

buildInitialHeap :: ( ?sz :: Int, ?th :: Int ) => [CoreScDefn] -> (TiHeap, TiGlobals)
buildInitialHeap scDefs = (heap2, scAddrs ++ primAddrs)
    where
        (heap1, scAddrs)   = mapAccumL allocateSc hInitial scDefs
        (heap2, primAddrs) = mapAccumL allocatePrim heap1 primitives

allocateSc :: TiHeap -> CoreScDefn -> (TiHeap, (Name, Addr))
allocateSc heap scDefn = case scDefn of
    (name, args, body) -> (heap', (name, addr))
        where
            (heap', addr) = hAlloc heap (NSupercomb name args body)

allocatePrim :: TiHeap -> (Name, Primitive) -> (TiHeap, (Name, Addr))
allocatePrim heap (name, prim) = (heap1, (name, addr))
    where
        (heap1, addr) = hAlloc heap (NPrim name prim)

{- | Evaluator -}

eval :: (?sz :: Int, ?th :: Int) => TiState -> [TiState]
eval state = state : rests
    where
        rests | tiFinal state = []
              | otherwise      = eval $ doAdmin $ doAdminTotalSteps $ step state

doAdmin :: (?sz :: Int, ?th :: Int) => TiState -> TiState
doAdmin state = bool id (trace "GC" gc) (state.heap.curAllocs > state.heap.threshold) state

step :: TiState -> TiState
step state = case map toLower $ head state.control of
    ""                -> state' { control = tail state.control }
    "c"               -> state' { control = repeat "" }
    s | all isDigit s -> state' { control = replicate (pred $ read s) "" ++ tail state.control }
      | otherwise     -> state' { control = tail state.control }
  where
        state' = dispatchNode 
                    apStep
                    scStep
                    numStep
                    indStep
                    primStep
                    dataStep
                    (error "step: NForward node")
                    (hLookup state.heap (fst (pop state.stack)))
                  $ state

numStep :: Int -> TiState -> TiState
numStep n state 
    | isEmptyStack state.dump = error "numStep: Number applied as a function"
    | otherwise = case popAndRestore state.stack state.dump of
        (stack1, dump1) -> setRuleId 7 $ state { stack = stack1, dump = dump1 }

apStep :: Addr -> Addr -> TiState -> TiState
apStep a1 a2 state = case hLookup state.heap a2 of
    NInd a3 -> setRuleId 8 $ state { heap = hUpdate state.heap a (NAp a1 a3) }
    _       -> setRuleId 1 $ state { stack = push a1 state.stack }
    where
        (a,_) = pop state.stack

scStep :: Name -> [Name] -> CoreExpr -> TiState -> TiState
scStep name args body state
    | state.stack.curDepth < succ argsLen
        = error "scStep: too few arguments given"
    | otherwise
        = doAdminScSteps $ setRuleId 3 $ state { stack = stack1, heap = heap1 }
    where
        argsLen  = length args
        stack1   = discard argsLen state.stack
        (root,_) = pop stack1
        heap1    = instantiateAndUpdate body root state.heap (bindings ++ state.globals)
        bindings = zip args (getargs state.heap state.stack)

indStep :: Addr -> TiState -> TiState
indStep addr state = setRuleId 4 $ state { stack = push addr (discard 1 state.stack) }

primStep :: Name -> Primitive -> TiState -> TiState
primStep name prim = prim

dataStep :: Tag -> [Addr] -> TiState -> TiState
dataStep tag contents state = state { stack = stack1, dump = dump1 }
    where
        (stack1, dump1) = popAndRestore state.stack state.dump

{- | Instantiation -}

instantiate :: CoreExpr
            -> TiHeap
            -> Assoc Name Addr
            -> (TiHeap, Addr)
instantiate expr heap env = dispatchCoreExpr
    (instantiateVar heap env)
    (instantiateNum heap env)
    (instantiateConstr heap env)
    (instantiateAp heap env)
    (instantiateLet heap env)
    (instantiateCase heap env)
    (instantiateLam heap env)
    expr

instantiateVar :: TiHeap -> Assoc Name Addr -> Name -> (TiHeap, Addr)
instantiateVar heap env name
    = (heap, aLookup env name (error ("instantiateVar: Undefined name " ++ show name)))

instantiateNum :: TiHeap -> Assoc Name Addr -> Int -> (TiHeap, Addr)
instantiateNum heap env num = hAlloc heap (NNum num)

instantiateConstr :: TiHeap -> Assoc Name Addr -> Tag -> Arity -> (TiHeap, Addr)
instantiateConstr heap env tag arity = hAlloc heap (NPrim "Constr" (primConstr tag arity))

instantiateAp :: TiHeap -> Assoc Name Addr -> CoreExpr -> CoreExpr -> (TiHeap, Addr)
instantiateAp heap env a b = hAlloc heap2 (NAp a1 a2)
    where
        (heap1, a1) = instantiate a heap  env
        (heap2, a2) = instantiate b heap1 env

instantiateLet :: TiHeap -> Assoc Name Addr -> IsRec -> Assoc Name CoreExpr -> CoreExpr -> (TiHeap, Addr)
instantiateLet heap env isrec defs body = instantiate body heap' env'
    where
        (heap', extraBindings) = mapAccumL instantiateRhs heap defs
        env' = extraBindings ++ env
        rhsEnv | isrec     = env'
               | otherwise = env
        instantiateRhs heap (name, rhs)
            = (heap1, (name, addr))
            where
                (heap1, addr) = instantiate rhs heap rhsEnv

instantiateCase :: TiHeap -> Assoc Name Addr -> CoreExpr -> [CoreAlter] -> (TiHeap, Addr)
instantiateCase heap env expr alters = error "Cannot instatiate case"

instantiateLam :: TiHeap -> Assoc Name Addr -> [Name] -> CoreExpr -> (TiHeap, Addr)
instantiateLam heap env vars body = error "Cannot instatiate lambda"

instantiateAndUpdate :: CoreExpr
                     -> Addr
                     -> TiHeap
                     -> Assoc Name Addr
                     -> TiHeap
instantiateAndUpdate expr updAddr heap env = dispatchCoreExpr
    (instUpdEVar updAddr heap env)
    (instUpdENum updAddr heap env)
    (instUpdEConstr updAddr heap env)
    (instUpdEAp updAddr heap env)
    (instUpdELet updAddr heap env)
    (instUpdECase updAddr heap env)
    (instUpdELam updAddr heap env)
    expr

instUpdEVar :: Addr
            -> TiHeap
            -> Assoc Name Addr
            -> Name
            -> TiHeap
instUpdEVar updAddr heap env v = hUpdate heap updAddr (NInd varAddr)
    where
        varAddr = aLookup env v (error ("undefined name " ++ show v))

instUpdENum :: Addr
            -> TiHeap
            -> Assoc Name Addr
            -> Int
            -> TiHeap
instUpdENum updAddr heap env n = hUpdate heap updAddr (NNum n)

instUpdEConstr :: Addr
               -> TiHeap
               -> Assoc Name Addr
               -> Tag
               -> Arity
               -> TiHeap
instUpdEConstr updAddr heap env tag arity
    = hUpdate heap updAddr (NPrim "Constr" (primConstr tag arity))

instUpdEAp :: Addr
           -> TiHeap
           -> Assoc Name Addr
           -> CoreExpr
           -> CoreExpr
           -> TiHeap
instUpdEAp updAddr heap env e1 e2 = hUpdate heap2 updAddr (NAp a1 a2)
    where
        (heap1, a1) = instantiate e1 heap  env
        (heap2, a2) = instantiate e2 heap1 env

instUpdELet :: Addr
            -> TiHeap
            -> Assoc Name Addr
            -> IsRec
            -> Assoc Name CoreExpr
            -> CoreExpr
            -> TiHeap
instUpdELet updAddr heap env isrec defs body = instantiateAndUpdate body updAddr heap1 env1
    where
        (heap1, extraBindings) = mapAccumL instantiateRhs heap defs
        env1 = extraBindings ++ env
        rhsEnv | isrec     = env1
               | otherwise = env
        instantiateRhs heap (name, rhs) = (heap1, (name, addr))
            where
                (heap1, addr) = instantiate rhs heap rhsEnv

instUpdECase :: Addr
             -> TiHeap
             -> Assoc Name Addr
             -> CoreExpr
             -> [CoreAlter]
             -> TiHeap
instUpdECase updAddr heap env expr alts = error "not implemented"

instUpdELam :: Addr
            -> TiHeap
            -> Assoc Name Addr
            -> [Name]
            -> CoreExpr
            -> TiHeap
instUpdELam updAddr heap env vars body = error "not implemented"

test :: (?sz :: Int, ?th :: Int) => String -> IO ()
test = interact . drive . run 

-- Gabage Collector (Mark-scan)

gc :: (?sz :: Int, ?th :: Int) => TiState -> TiState
gc state = case evacuateStack state.heap hInitial state.stack of
    ((from1, to1), stack1) -> case evacuateDump from1 to1 state.dump of
        ((from2, to2), dump1)  -> case evacuateGlobals from2 to2 state.globals of
            ((from3, to3), globals1) -> state { stack = stack1
                                              , dump = dump1
                                              , heap = scavengeHeap from3 to3
                                              , globals = globals1
                                              , stats = incGcCount state.stats
                                              }

evacuateStack :: TiHeap -> TiHeap -> TiStack -> ((TiHeap, TiHeap), TiStack)
evacuateStack from to stack = case mapAccumL evacuateFrom (from, to) stack.stkItems of
    (heaps', addrs') -> (heaps', stack { stkItems = addrs'})

evacuateDump :: TiHeap -> TiHeap -> TiDump -> ((TiHeap, TiHeap), TiDump)
evacuateDump from to dump = ((from, to), dump)

evacuateGlobals :: TiHeap -> TiHeap -> TiGlobals -> ((TiHeap, TiHeap), TiGlobals)
evacuateGlobals from to globals = mapAccumL evacuateFrom_ (from, to) globals
    where
        evacuateFrom_ heaps (name, addr) = case evacuateFrom heaps addr of
            (heaps1, addr1) -> (heaps, (name, addr1))

evacuateFrom :: (TiHeap, TiHeap) -> Addr -> ((TiHeap, TiHeap), Addr)
evacuateFrom (from, to) a = case hLookup from a of
    node -> case hAlloc to node of
        (to1, a') -> case hUpdate from a (NForward a') of
            from1     -> case node of
                NAp b c   -> case evacuateFrom (from1, to1) b of
                    ((from2, to2), b') -> case evacuateFrom (from2, to2) c of
                        ((from3, to3), c')  -> 

{-
from                    --> alloc -->  to
    addr : NInd ind                        addr' : NInd ind

from                                   to
    addr : NForward addr'                  addr' : node
    ind  : node                            

from                                   to
    addr : NForward addr'                  addr' : node
    ind  : NForward addr'



-}

scavengeHeap :: TiHeap -> TiHeap -> TiHeap
scavengeHeap from to = foldl (phi from) to to.assocs
    where
        phi hfrom hto (addr, node) = dispatchNode
            (\ addr1 addr2 -> case hLookup hfrom addr1 of
                NForward fwd1  -> case hLookup hfrom addr2 of
                    NForward fwd2  -> hUpdate hto addr (NAp fwd1 fwd2)
                    _              -> error "Not NForward!"
                _              -> error "Not NForward!")
            (\ sc args e -> hto)
            (\ n -> hto)
            (\ addr1 -> error "NInd!")
            (\ name prim -> hto)
            (\ tag args -> case map (psi hfrom) args of
                    args' -> hUpdate hto addr (NData tag args'))
            (\ fwd -> error "NForward!")
            node 
            where
                psi h a = case hLookup h a of
                    NForward fwd -> fwd
                    _            -> error "Not NForward!"
