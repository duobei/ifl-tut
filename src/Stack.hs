{-# LANGUAGE NoFieldSelectors #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedRecordDot #-}
module Stack
    where

import Data.Bool
import Data.List.Extra

data Stack a
    = Stack
    { maxDepth :: Int
    , curDepth :: Int
    , stkItems :: [a]
    } deriving Show

emptyStack :: Stack a
emptyStack = Stack 0 0 []

singletonStack :: a -> Stack a
singletonStack x = push x emptyStack

isEmptyStack :: Stack a -> Bool
isEmptyStack stk = null stk.stkItems

isSingletonStack :: Stack a -> Bool
isSingletonStack stk = not (isEmptyStack stk) 
                    && isEmptyStack (snd (pop stk))

push :: a -> Stack a -> Stack a
push x stk = stk
    { maxDepth = stk.maxDepth `max` succ stk.curDepth
    , curDepth = succ stk.curDepth
    , stkItems = x : stk.stkItems
    }

pop :: Stack a -> (a, Stack a)
pop stk = bool (list undefined phi stk.stkItems)
               (error "pop: empty stack")
               (isEmptyStack stk)
    where
        phi x xs = (x, stk { curDepth = pred stk.curDepth, stkItems = xs })

discard :: Int -> Stack a -> Stack a
discard 0 stk = stk
discard n stk = stk { curDepth = subtract n stk.curDepth `max` 0
                    , stkItems = drop n stk.stkItems
                    }
