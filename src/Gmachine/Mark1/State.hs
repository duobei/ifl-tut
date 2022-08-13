{-# LANGUAGE ImplicitParams #-}
{-# LANGUAGE NoFieldSelectors #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedRecordDot #-}
module Gmachine.Mark1.State
    where

import Language
import Heap
import Stack
import Utils

import Gmachine.Mark1.Code
import Gmachine.Mark1.Node

--

data GmState
    = GmState
    { code    :: GmCode
    , stack   :: GmStack
    , heap    :: GmHeap
    , globals :: GmGlobals
    , stats   :: GmStats
    , ruleid  :: GmRuleId
    }

--

type GmStack = Stack Addr

--

type GmHeap = Heap Node

--

type GmGlobals = Assoc Name Addr

--

data GmStats
    = GmStats
    { steps :: Int 
    }

statInitial :: GmStats
statInitial = GmStats { steps = 0 }

statIncSteps :: GmStats -> GmStats
statIncSteps stats = stats { steps = succ stats.steps }

--

type GmRuleId = Int

ruleTable :: Assoc GmRuleId String
ruleTable 
    = [ (0, "Initial Stats")
      , (1, "Rule (3,5): Pushglobal")
      , (2, "Rule (3,6): Pushint")
      , (3, "Rule (3.7): Mkap")
      , (4, "Rule (3.8): Push")
      , (5, "Rule (3.9): Slide")
      , (6, "Rule (3.10): Unwind NNum")
      , (7, "Rule (3.11): Unwind NAp")
      , (8, "rule (3.12): Unwind NGlobal")
      ]
