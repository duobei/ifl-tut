{-# LANGUAGE ImplicitParams #-}
module Main where

import System.Environment
import Template.Mark5rvp.Machine

main :: IO ()
main = do
    { fp:_ <- getArgs
    ; let ?sz = defaultHeapSize
    ; let ?th = defaultThreshold
    ; interact . drive . run =<< readFile fp
    }

defaultHeapSize :: Int
defaultHeapSize = 1024

defaultThreshold :: Int
defaultThreshold = 256
