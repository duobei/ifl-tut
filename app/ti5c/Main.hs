module Main where

import System.Environment
import Template.Mark5c.Machine

main :: IO ()
main = do
    { fp:_ <- getArgs
    ; interact . drive . run =<< readFile fp
    }
