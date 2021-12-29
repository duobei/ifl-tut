module Iseq
    where

import Utils

class Iseq iseq where
    iNil :: iseq
    iStr :: String -> iseq
    iAppend  :: iseq -> iseq -> iseq
    iNewline :: iseq
    iIndent  :: iseq -> iseq
    iDisplay :: iseq -> String

infixr 5 `iAppend`

iConcat :: Iseq iseq => [iseq] -> iseq
iConcat = foldr iAppend iNil

iInterleave :: Iseq iseq => iseq -> [iseq] -> iseq
iInterleave sep iseqs = case iseqs of 
    []      -> iNil
    [iseq]  -> iseq
    iseq:rs -> iseq `iAppend` sep `iAppend` iInterleave iseq rs

iParen :: Iseq iseq => iseq -> iseq
iParen iseq = iConcat [ iStr "(", iseq, iStr ")" ]

iSpace :: Iseq iseq => iseq
iSpace = iStr " "

iNum :: Iseq iseq => Int -> iseq
iNum = iStr . show

iFWNum :: Iseq iseq => Int -> Int -> iseq
iFWNum width n = iStr 
    $ reverse $ take width $ foldl (flip (:)) (repeat ' ') (show n)

iLayn :: Iseq iseq => [iseq] -> iseq
iLayn seqs
  = iConcat (zipWith layItem [1..] seqs)
    where
      layItem n seq
        = iConcat [ iFWNum 4 n, iStr ") ", iIndent seq, iNewline ]
  
iLayn' :: Iseq iseq => [iseq] -> [iseq]
iLayn' seqs = zipWith layItem [1..] seqs
    where
      layItem n seq
        = iConcat [ iFWNum 4 n, iStr ") ", iIndent seq, iNewline ]

{- | instance of Iseq
-}
data IseqRep
    = INil
    | IStr String
    | IAppend IseqRep IseqRep
    | IIndent IseqRep
    | INewline
    deriving (Eq, Show)

instance Iseq IseqRep where
    iNil =  INil
    iStr "" = INil
    iStr cs = case break ('\n' ==) cs of
        (_, "")   -> IStr cs
        (xs,_:ys) -> case xs of
            "" -> INewline `iAppend` iStr ys
            _  -> IStr xs `iAppend` INewline `iAppend` iStr ys
    iAppend INil seq2 = seq2
    iAppend seq1 INil = seq1
    iAppend seq1 seq2 = IAppend seq1 seq2
    iIndent seq = IIndent seq
    iNewline = INewline
    iDisplay seq = flatten 0 [(seq, 0)]

flatten :: Int
        -> [(IseqRep, Int)]
        -> String
flatten col iseqs = case iseqs of
    (INil, indent) : seqs   -> flatten col seqs
    (IStr s, indent) : seqs -> s ++ flatten (col + length s) seqs
    (IAppend seq1 seq2, indent) : seqs
        -> flatten col ((seq1, indent) : (seq2, indent) : seqs)
    (INewline, indent) : seqs
        -> '\n' : (space indent ++ flatten indent seqs)
    (IIndent seq, indent) : seqs
        -> flatten col ((seq, col) : seqs)
    [] -> ""