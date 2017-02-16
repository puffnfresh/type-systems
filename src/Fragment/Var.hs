{-|
Copyright   : (c) Dave Laing, 2017
License     : BSD3
Maintainer  : dave.laing.80@gmail.com
Stability   : experimental
Portability : non-portable
-}
{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE DeriveFoldable #-}
{-# LANGUAGE DeriveTraversable #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE ConstraintKinds #-}
module Fragment.Var (
    PtFWild(..)
  , AsPtWild(..)
  , PtVarContext
  , ptVarFragment
  , HasTmVarSupply(..)
  , ToTmVar(..)
  , freshTmVar
  , tmVar
  , TermContext(..)
  , emptyTermContext
  , HasTermContext(..)
  , AsUnboundTermVariable(..)
  , lookupTerm
  , insertTerm
  , TmVarContext
  , tmVarFragment
  ) where

import Control.Monad.State (MonadState)
import Control.Monad.Reader (MonadReader)
import Control.Monad.Except (MonadError)

import qualified Data.Map as M
import qualified Data.Text as T

import Control.Lens
import Control.Monad.Error.Lens

import Bound
import Data.Deriving

import Fragment
import Fragment.Ast
import Util

data PtFWild (f :: * -> *) a =
    PtWildF
  deriving (Eq, Ord, Show, Functor, Foldable, Traversable)

makePrisms ''PtFWild

deriveEq1 ''PtFWild
deriveOrd1 ''PtFWild
deriveShow1 ''PtFWild

instance Bound PtFWild where
  PtWildF >>>= _ = PtWildF

instance Bitransversable PtFWild where
  bitransverse _ _ PtWildF = pure PtWildF

class AsPtWild pt where
  _PtWildP :: Prism' (pt k a) (PtFWild k a)

  _PtWild :: Prism' (Pattern pt a) ()
  _PtWild = _PtTree . _PtWildP . _PtWildF

instance AsPtWild PtFWild where
  _PtWildP = id

matchWild :: AsPtWild pt => Pattern pt a -> Term ty pt tm a -> Maybe [Term ty pt tm a]
matchWild p _ = do
  _ <- preview _PtWild p
  return []

checkWild :: (Monad m, AsPtWild pt) => Pattern pt a -> Type ty a -> Maybe (m [Type ty a])
checkWild p _ = do
  _ <- preview _PtWild p
  return $
    return []

matchVar :: Pattern pt a -> Term ty pt tm a -> Maybe [Term ty pt tm a]
matchVar p tm = do
  _ <- preview _PtVar p
  return [tm]

checkVar :: Monad m => Pattern pt a -> Type ty a -> Maybe (m [Type ty a])
checkVar p ty = do
  _ <- preview _PtVar p
  return $
    return [ty]

type PtVarContext e s r m (ty :: (* -> *) -> * -> *) pt (tm :: ((* -> *) -> * -> *) -> ((* -> *) -> * -> *) -> (* -> *) -> * -> *) a = (Monad m, AsPtWild pt)

ptVarFragment :: PtVarContext e s r m ty pt tm a => FragmentInput e s r m ty pt tm a
ptVarFragment =
  FragmentInput
    []
    []
    []
    [ PMatchBase matchWild
    , PMatchBase matchVar
    ]
    [ PCheckBase checkWild
    , PCheckBase checkVar
    ]

-- State

class HasTmVarSupply s where
  tmVarSupply :: Lens' s Int

instance HasTmVarSupply Int where
  tmVarSupply = id

class ToTmVar a where
  toTmVar :: Int -> a

instance ToTmVar T.Text where
  toTmVar x = T.append "x" (T.pack . show $ x)

freshTmVar :: (MonadState s m, HasTmVarSupply s, ToTmVar a) => m a
freshTmVar = do
  x <- use tmVarSupply
  tmVarSupply %= succ
  return $ toTmVar x

-- Context

data TermContext ty tmV tyV = TermContext (M.Map tmV (Type ty tyV))

emptyTermContext :: TermContext ty tmV tyV
emptyTermContext = TermContext M.empty

instance HasTermContext (TermContext ty tmV tyV) ty tmV tyV where
  termContext = id

class HasTermContext l ty tmV tyV | l -> ty, l -> tmV, l -> tyV where
  termContext :: Lens' l (TermContext ty tmV tyV)

class AsUnboundTermVariable e tm | e -> tm where
  _UnboundTermVariable :: Prism' e tm

lookupTerm :: (Ord tmV, MonadReader r m, MonadError e m, HasTermContext r ty tmV tyV, AsUnboundTermVariable e tmV) => tmV -> m (Type ty tyV)
lookupTerm v = do
  TermContext m <- view termContext
  case M.lookup v m of
    Nothing -> throwing _UnboundTermVariable v
    Just ty -> return ty

insertTerm :: Ord tmV => tmV -> Type ty tyV -> TermContext ty tmV tyV -> TermContext ty tmV tyV
insertTerm v ty (TermContext m) = TermContext (M.insert v ty m)

-- Rules

inferTmVar :: (Ord a, MonadReader r m, MonadError e m, HasTermContext r ty a a, AsUnboundTermVariable e a) => Term ty pt tm a -> Maybe (m (Type ty a))
inferTmVar tm = do
  v <- preview _TmVar tm
  return $ lookupTerm v

type TmVarContext e s r m ty (pt :: (* -> *) -> * -> *) (tm :: ((* -> *) -> * -> *) -> ((* -> *) -> * -> *) -> (* -> *) -> * -> *) a = (Ord a, MonadReader r m, HasTermContext r ty a a, MonadError e m, AsUnboundTermVariable e a)

tmVarFragment :: TmVarContext e s r m ty pt tm a
            => FragmentInput e s r m ty pt tm a
tmVarFragment =
  FragmentInput
    [] [] [InferBase inferTmVar] [] []

-- Helpers

tmVar :: a -> Term ty pt tm a
tmVar = review _TmVar
