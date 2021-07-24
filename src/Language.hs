{- |
module:       Language
copyright:    (c) Nobuo Yamashita 2021
license:      BSD-3
maintainer:   nobsun@sampou.org
stability:    experimental
-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE ScopedTypeVariables #-}
module Language where

import Data.Bool
import Data.Char
import Data.Maybe
import Utils

{- コア言語の式 -}

data Expr a
  = EVar Name                 -- ^ 変数
  | ENum Int                  -- ^ 数
  | EConstr                   -- ^ 構成子
      Int                       -- ^ タグ
      Int                       -- ^ アリティ
  | EAp (Expr a) (Expr a)     -- ^ 適用
  | ELet                      -- ^ let(rec)式
      IsRec                     -- ^ 再帰的か
      [(a, Expr a)]             -- ^ 定義
      (Expr a)                  -- ^ let(rec)式の本体
  | ECase                     -- ^ case式
      (Expr a)                  -- ^ 分析対象の式
      [Alter a]                 -- ^ 選択肢
  | ELam                      -- ^ λ抽象
      [a]                       -- ^ 束縛変数のリスト
      (Expr a)                  -- ^ λ抽象本体

type CoreExpr = Expr Name

type Name = String

type IsRec = Bool
recursive :: IsRec
recursive = True
nonRecursive :: IsRec
nonRecursive = False

{- バインダ -}

bindersOf :: [(a, b)] -> [a]
bindersOf defns = [ name | (name, rhs) <- defns ]

rhssOf :: [(a, b)] -> [b]
rhssOf defns = [ rhs | (name, rhs) <- defns ]

{- 選択肢 -}

type Alter a = (Int, [a], Expr a)
type CoreAlter = Alter Name

{- アトミック式の判別 -}

isAtomicExpr :: Expr a -> Bool
isAtomicExpr = \ case
  EVar _ -> True
  ENum _ -> True
  _      -> False

{- サンプル式 -}
varSampleE :: CoreExpr
varSampleE = EVar "var"

numSampleE :: CoreExpr
numSampleE = ENum 57

constrSampleE10 :: CoreExpr
constrSampleE10 = EConstr 1 0
constrSampleE21:: CoreExpr
constrSampleE21 = EConstr 2 1

appInfixSampleE :: CoreExpr
appInfixSampleE = EAp (EAp (EVar "<") 
                           (EAp (EAp (EVar "+") (EVar "x")) (EVar "y")))
                      (EAp (EAp (EVar "*") (EVar "p")) (EAp (EVar "length") (EVar "xs")))

appInfixSampleE' :: CoreExpr
appInfixSampleE' = EAp (EAp (EVar "/") (EAp (EAp (EVar "/") (ENum 12)) (ENum 2))) (EAp (EAp (EVar "/") (ENum 6)) (ENum 3))

appInfixSampleE'' :: CoreExpr
appInfixSampleE'' = EAp (EAp (EVar "/") (EAp (EAp (EVar "*") (ENum 12)) (ENum 2))) (EAp (EAp (EVar "*") (ENum 6)) (ENum 3))

appInfixSampleE''' :: CoreExpr
appInfixSampleE''' = EAp (EAp (EVar "*") (EAp (EAp (EVar "*") (ENum 12)) (ENum 2))) (EAp (EAp (EVar "*") (ENum 6)) (ENum 3))

letSampleE :: CoreExpr
letSampleE = ELet recursive 
                  [ ("y", EAp (EAp (EVar "+") (EVar "x")) (ENum 1))
                  , ("z", EAp (EAp (EVar "*") (EVar "Y")) (ENum 2))
                  ]
                  (EVar "z")

caseSampleE :: CoreExpr
caseSampleE = ECase (EVar "xxs")
                    [ (1, [], ENum 0)
                    , (2, ["x", "xs"], EAp (EAp (EVar "+") (ENum 1)) (EAp (EVar "length") (EVar "xs")))
                    ]

lambdaSampleE :: CoreExpr
lambdaSampleE = ELam ["x", "y"] (EAp (EAp (EConstr 1 2) (EVar "x")) (EVar "y"))

{- プログラム -}

type Program a = [ScDefn a]
type CoreProgram = Program Name

{- スーパーコンビネータ定義 -}

type ScDefn a = (Name, [a], Expr a)
type CoreScDefn = ScDefn Name

{- サンプル -}
sampleProg :: CoreProgram
sampleProg
  = [ ("main",   [],    EAp (EVar "double") (ENum 21))
    , ("double", ["x"], EAp (EAp (EVar "+") (EVar "x")) (EVar "x"))
    ]

{- コア言語の標準プレリュード -}

preludeCode :: String
preludeCode = unlines
  [ "I x = x ;"
  , "K x y = x ;"
  , "K1 x y = y ;"
  , "S f g x = f x (g x) ;"
  , "compose f g x = f (g x) ;"
  , "twice f = compose f f"
  ]

preludeDefs :: CoreProgram
preludeDefs 
  = [ ("I",  ["x"], EVar "x")
    , ("K",  ["x", "y"], EVar "x")
    , ("K1", ["x", "y"], EVar "y")
    , ("S",  ["f", "g", "x"], EAp (EAp (EVar "f") (EVar "x"))
                                  (EAp (EVar "g") (EVar "x")))
    , ("compose", ["f", "g", "x"], EAp (EVar "f") (EAp (EVar "g") (EVar "x")))
    , ("twice", ["f"], EAp (EAp (EVar "compose") (EVar "f")) (EVar "f"))
    ]

{- プリティプリンタ -}

pprint :: CoreProgram -> String
pprint = iDisplay . pprProgram

pprProgram :: CoreProgram -> IseqRep
pprProgram prog = iInterleave (iAppend (iStr " ;") iNewline) (map pprSc prog)

pprSc :: CoreScDefn -> IseqRep
pprSc (name, args, body)
  = iConcat [ iStr name, if null args then iNil else iAppend iSpace (pprArgs args),
              iStr " = ", iIndent (pprExpr (0, N) body) ]

pprArgs :: [Name] -> IseqRep
pprArgs args = iConcat (map (iAppend iSpace . iStr) args)

--

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
iInterleave sep = \ case
  []       -> iNil
  [seq]    -> seq
  seq:seqs -> seq `iAppend` sep `iAppend` iInterleave sep seqs

iParen :: Iseq iseq => iseq -> iseq
iParen seq = iConcat [ iStr "(", seq, iStr ")" ]

iSpace :: Iseq iseq => iseq
iSpace = iStr " "

iNum :: Iseq iseq => Int -> iseq
iNum = iStr . show

iFWNum :: Iseq iseq => Int -> Int -> iseq
iFWNum width n = iStr (space (width - length digits) ++ digits)
  where
    digits = show n

iLayn :: Iseq iseq => [iseq] -> iseq
iLayn seqs
  = iConcat (zipWith layItem [1..] seqs)
    where
      layItem n seq
        = iConcat [ iFWNum 4 n, iStr ") ", iIndent seq, iNewline ]
  
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
flatten col = \ case
  (INil, indent) : seqs   -> flatten col seqs
  (IStr s, indent) : seqs -> s ++ flatten (col + length s) seqs
  (IAppend seq1 seq2, indent) : seqs
    -> flatten col ((seq1, indent) : (seq2, indent) : seqs)
  (INewline, indent) : seqs
    -> '\n' : (space indent ++ flatten indent seqs)
  (IIndent seq, indent) : seqs
    -> flatten col ((seq, col) : seqs)
  [] -> ""

-- | Pretty printer for CoreExpr

binOps :: [(Name, Fixity)]
binOps = [ ("*", (5, R))
         , ("/", (5, N))
         , ("+", (4, R))
         , ("-", (4, N))
         , ("==", (3, N)), ("/=", (3, N))
         , ("<", (3, N)), ("<=", (3, N))
         , (">=", (3, N)), (">", (3, N))
         , ("&&", (2, N))
         , ("||", (1, N)) ]

type Fixity = (Priority, Associativity)
type Priority = Int
data Associativity
  = N | L | R | O deriving (Eq, Ord, Show)


{- |
>>> es1 = [varSampleE, numSampleE]
>>> es2 = [constrSampleE10, constrSampleE21]
>>> es3 = [appInfixSampleE, appInfixSampleE', appInfixSampleE'', appInfixSampleE''']
>>> es4 = [letSampleE, caseSampleE, lambdaSampleE]
>>> es = concat [es1,es2,es3,es4]
>>> putStrLn $ iDisplay $ iLayn $ map (pprExpr (0, N)) es
   1) var
   2) 57
   3) Pack{1,0}
   4) Pack{2,1}
   5) x + y < p * length xs
   6) (12 / 2) / (6 / 3)
   7) (12 * 2) / (6 * 3)
   8) 12 * 2 * 6 * 3
   9) letrec
        y = x + 1;
        z = Y * 2
      in z
  10) case xxs of
        <1> -> 0;
        <2> x xs -> 1 + length xs
  11) (\ x y -> Pack{1,2} x y)
<BLANKLINE>
-}
pprExpr :: Fixity -> CoreExpr -> IseqRep
pprExpr fx@(p, a) = \ case
  EVar v -> iStr v
  ENum n -> iNum n
  EConstr tag arity
    -> iConcat [ iStr "Pack{", iNum tag, iStr ",", iNum arity, iStr "}" ]
  EAp (EAp (EVar op) e1) e2
    | isJust mfx -> bool id iParen (fx > fx') infixexpr
    where
      mfx = lookup op binOps
      fx'@(p', a') = fromJust mfx
      fx'' = (p', bool id (const O) (a' == N) a')
      infixexpr = iConcat [ pprExpr fx'' e1
                          , iSpace, iStr op, iSpace
                          , pprExpr fx'' e2 ]
  EAp e1 e2
    | fx <= (6, L) -> appexpr
    | otherwise    -> iParen appexpr
    where
      appexpr = iConcat [ pprExpr (6, L) e1, iStr " ", pprExpr (6, O) e2]
  ELet isrec defns expr
    | p <= 0    -> letexpr
    | otherwise -> iParen letexpr
    where
      letexpr = iConcat [ iStr keyword, iNewline
                        , iStr "  ", iIndent (pprDefns defns), iNewline
                        , iStr "in ", pprExpr (0, N) expr ]
      keyword | isrec     = "letrec"
              | otherwise = "let"
  ECase e alts
    | p <= 0    -> caseexpr
    | otherwise -> iParen caseexpr
    where
      caseexpr = iConcat [ iStr "case ", iIndent (pprExpr (0, N) e), iStr " of", iNewline,
                           iStr "  ", iIndent (iInterleave iNl (map pprAlt alts)) ]
      iNl = iConcat [ iStr ";", iNewline ]
      pprAlt (tag, args, rhs)
        = iConcat [ iStr "<", iNum tag, iStr ">",
                    pprArgs args, iStr " -> ",
                    iIndent (pprExpr (0, N) rhs) ]
  ELam args body
    | p <= 0    -> lambda
    | otherwise -> iParen lambda
    where
      lambda = iConcat [ iStr "(\\", pprArgs args, iStr " -> ", iIndent (pprExpr (0,N) body),
                         iStr ")" ]

pprDefns :: [(Name, CoreExpr)] -> IseqRep
pprDefns defns
  = iInterleave sep (map pprDefn defns)
    where
      sep = iConcat [ iStr ";", iNewline ]

pprDefn :: (Name, CoreExpr) -> IseqRep
pprDefn (name, expr)
  = iConcat [ iStr name, iStr " = ", iIndent (pprExpr (0, N) expr) ]
