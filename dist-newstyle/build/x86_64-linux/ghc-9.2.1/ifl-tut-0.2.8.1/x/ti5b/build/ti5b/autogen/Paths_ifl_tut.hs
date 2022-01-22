{-# LANGUAGE CPP #-}
{-# LANGUAGE NoRebindableSyntax #-}
{-# OPTIONS_GHC -fno-warn-missing-import-lists #-}
{-# OPTIONS_GHC -w #-}
module Paths_ifl_tut (
    version,
    getBinDir, getLibDir, getDynLibDir, getDataDir, getLibexecDir,
    getDataFileName, getSysconfDir
  ) where


import qualified Control.Exception as Exception
import qualified Data.List as List
import Data.Version (Version(..))
import System.Environment (getEnv)
import Prelude


#if defined(VERSION_base)

#if MIN_VERSION_base(4,0,0)
catchIO :: IO a -> (Exception.IOException -> IO a) -> IO a
#else
catchIO :: IO a -> (Exception.Exception -> IO a) -> IO a
#endif

#else
catchIO :: IO a -> (Exception.IOException -> IO a) -> IO a
#endif
catchIO = Exception.catch

version :: Version
version = Version [0,2,8,1] []

getDataFileName :: FilePath -> IO FilePath
getDataFileName name = do
  dir <- getDataDir
  return (dir `joinFileName` name)

getBinDir, getLibDir, getDynLibDir, getDataDir, getLibexecDir, getSysconfDir :: IO FilePath



bindir, libdir, dynlibdir, datadir, libexecdir, sysconfdir :: FilePath
bindir     = "/home/nobsun/.cabal/bin"
libdir     = "/home/nobsun/.cabal/lib/x86_64-linux-ghc-9.2.1/ifl-tut-0.2.8.1-inplace-ti5b"
dynlibdir  = "/home/nobsun/.cabal/lib/x86_64-linux-ghc-9.2.1"
datadir    = "/home/nobsun/.cabal/share/x86_64-linux-ghc-9.2.1/ifl-tut-0.2.8.1"
libexecdir = "/home/nobsun/.cabal/libexec/x86_64-linux-ghc-9.2.1/ifl-tut-0.2.8.1"
sysconfdir = "/home/nobsun/.cabal/etc"

getBinDir     = catchIO (getEnv "ifl_tut_bindir")     (\_ -> return bindir)
getLibDir     = catchIO (getEnv "ifl_tut_libdir")     (\_ -> return libdir)
getDynLibDir  = catchIO (getEnv "ifl_tut_dynlibdir")  (\_ -> return dynlibdir)
getDataDir    = catchIO (getEnv "ifl_tut_datadir")    (\_ -> return datadir)
getLibexecDir = catchIO (getEnv "ifl_tut_libexecdir") (\_ -> return libexecdir)
getSysconfDir = catchIO (getEnv "ifl_tut_sysconfdir") (\_ -> return sysconfdir)




joinFileName :: String -> String -> FilePath
joinFileName ""  fname = fname
joinFileName "." fname = fname
joinFileName dir ""    = dir
joinFileName dir fname
  | isPathSeparator (List.last dir) = dir ++ fname
  | otherwise                       = dir ++ pathSeparator : fname

pathSeparator :: Char
pathSeparator = '/'

isPathSeparator :: Char -> Bool
isPathSeparator c = c == '/'
