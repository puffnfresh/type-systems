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
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE OverloadedStrings #-}
module Fragment.Pair (
    TyFPair(..)
  , AsTyPair(..)
  , PtFPair(..)
  , AsPtPair(..)
  , TmFPair(..)
  , AsTmPair(..)
  , AsExpectedTyPair(..)
  , PairContext
  , pairFragmentLazy
  , pairFragmentStrict
  , tyPair
  , ptPair
  , tmPair
  , tmFst
  , tmSnd
  ) where

import Control.Monad.Except (MonadError)

import Control.Lens
import Control.Monad.Error.Lens (throwing)

import Bound
import Data.Functor.Classes
import Data.Deriving

import Fragment

data TyFPair f a =
  TyPairF (f a) (f a)
  deriving (Eq, Ord, Show, Functor, Foldable, Traversable)

makePrisms ''TyFPair

instance Eq1 f => Eq1 (TyFPair f) where
  liftEq = $(makeLiftEq ''TyFPair)

instance Ord1 f => Ord1 (TyFPair f) where
  liftCompare = $(makeLiftCompare ''TyFPair)

instance Show1 f => Show1 (TyFPair f) where
  liftShowsPrec = $(makeLiftShowsPrec ''TyFPair)

instance Bound TyFPair where
  TyPairF x y >>>= f = TyPairF (x >>= f) (y >>= f)

class AsTyPair ty where
  _TyPairP :: Prism' (ty a) (TyFPair ty a)

  _TyPair :: Prism' (ty a) (ty a, ty a)
  _TyPair = _TyPairP . _TyPairF

instance AsTyPair f => AsTyPair (TyFPair f) where
  _TyPairP = id . _TyPairP

data PtFPair f a =
    PtPairF (f a) (f a)
  deriving (Eq, Ord, Show, Functor, Foldable, Traversable)

makePrisms ''PtFPair

instance Eq1 f => Eq1 (PtFPair f) where
  liftEq = $(makeLiftEq ''PtFPair)

instance Ord1 f => Ord1 (PtFPair f) where
  liftCompare = $(makeLiftCompare ''PtFPair)

instance Show1 f => Show1 (PtFPair f) where
  liftShowsPrec = $(makeLiftShowsPrec ''PtFPair)

class AsPtPair pt where
  _PtPairP :: Prism' (pt a) (PtFPair pt a)

  _PtPair :: Prism' (pt a) (pt a, pt a)
  _PtPair = _PtPairP . _PtPairF

instance AsPtPair pt => AsPtPair (PtFPair pt) where
  _PtPairP = id . _PtPairP

data TmFPair f a =
    TmPairF (f a) (f a)
  | TmFstF (f a)
  | TmSndF (f a)
  deriving (Eq, Ord, Show, Functor, Foldable, Traversable)

makePrisms ''TmFPair

instance Eq1 f => Eq1 (TmFPair f) where
  liftEq = $(makeLiftEq ''TmFPair)

instance Ord1 f => Ord1 (TmFPair f) where
  liftCompare = $(makeLiftCompare ''TmFPair)

instance Show1 f => Show1 (TmFPair f) where
  liftShowsPrec = $(makeLiftShowsPrec ''TmFPair)

instance Bound TmFPair where
  TmPairF x y >>>= f = TmPairF (x >>= f) (y >>= f)
  TmFstF x >>>= f = TmFstF (x >>= f)
  TmSndF x >>>= f = TmSndF (x >>= f)

class AsTmPair tm where
  _TmPairP :: Prism' (tm a) (TmFPair tm a)

  _TmPair :: Prism' (tm a) (tm a, tm a)
  _TmPair = _TmPairP . _TmPairF

  _TmFst :: Prism' (tm a) (tm a)
  _TmFst = _TmPairP . _TmFstF

  _TmSnd :: Prism' (tm a) (tm a)
  _TmSnd = _TmPairP . _TmSndF

instance AsTmPair f => AsTmPair (TmFPair f) where
  _TmPairP = id . _TmPairP

-- Errors

class AsExpectedTyPair e ty | e -> ty where
  _ExpectedTyPair :: Prism' e ty

expectTyPair :: (MonadError e m, AsExpectedTyPair e (ty a), AsTyPair ty) => ty a -> m (ty a, ty a)
expectTyPair ty =
  case preview _TyPair ty of
    Just (ty1, ty2) -> return (ty1, ty2)
    _ -> throwing _ExpectedTyPair ty

-- Rules

stepFstLazy :: AsTmPair tm => tm a -> Maybe (tm a)
stepFstLazy tm = do
  tmP <- preview _TmFst tm
  (tm1, _) <- preview _TmPair tmP
  return tm1

stepSndLazy :: AsTmPair tm => tm a -> Maybe (tm a)
stepSndLazy tm = do
  tmP <- preview _TmSnd tm
  (_, tm2) <- preview _TmPair tmP
  return tm2

-- TODO check this, there might be more rules
evalRulesLazy :: AsTmPair tm => FragmentInput e s r m ty p tm a
evalRulesLazy =
  FragmentInput [] [EvalBase stepFstLazy, EvalBase stepSndLazy] [] [] []

valuePair :: AsTmPair tm => (tm a -> Maybe (tm a)) -> tm a -> Maybe (tm a)
valuePair valueFn tm = do
  tmP <- preview _TmFst tm
  (tm1, tm2) <- preview _TmPair tmP
  v1 <- valueFn tm1
  v2 <- valueFn tm2
  return $ review _TmPair (v1, v2)

stepFstStrict :: AsTmPair tm => (tm a -> Maybe (tm a)) -> tm a -> Maybe (tm a)
stepFstStrict stepFn tm = do
  tmP <- preview _TmFst tm
  tmP' <- stepFn tmP
  return $ review _TmFst tmP'

stepSndStrict :: AsTmPair tm => (tm a -> Maybe (tm a)) -> tm a -> Maybe (tm a)
stepSndStrict stepFn tm = do
  tmP <- preview _TmSnd tm
  tmP' <- stepFn tmP
  return $ review _TmSnd tmP'

stepElimFstStrict :: AsTmPair tm => (tm a -> Maybe (tm a)) -> tm a -> Maybe (tm a)
stepElimFstStrict valueFn tm = do
  tmP <- preview _TmFst tm
  (tm1, tm2) <- preview _TmPair tmP
  v1 <- valueFn tm1
  _ <- valueFn tm2
  return v1

stepElimSndStrict :: AsTmPair tm => (tm a -> Maybe (tm a)) -> tm a -> Maybe (tm a)
stepElimSndStrict valueFn tm = do
  tmP <- preview _TmSnd tm
  (tm1, tm2) <- preview _TmPair tmP
  _ <- valueFn tm1
  v2 <- valueFn tm2
  return v2

stepPair1 :: AsTmPair tm => (tm a -> Maybe (tm a)) -> tm a -> Maybe (tm a)
stepPair1 stepFn tm = do
  (tm1, tm2) <- preview _TmPair tm
  tm1' <- stepFn tm1
  return $ review _TmPair (tm1', tm2)

stepPair2 :: AsTmPair tm => (tm a -> Maybe (tm a)) -> (tm a -> Maybe (tm a)) -> tm a -> Maybe (tm a)
stepPair2 valueFn stepFn tm = do
  (tm1, tm2) <- preview _TmPair tm
  v1 <- valueFn tm1
  tm2' <- stepFn tm2
  return $ review _TmPair (v1, tm2')

evalRulesStrict :: AsTmPair tm => FragmentInput e s r m ty p tm a
evalRulesStrict =
  FragmentInput
    [ ValueRecurse valuePair ]
    [ EvalStep stepFstStrict
    , EvalStep stepSndStrict
    , EvalValue stepElimFstStrict
    , EvalValue stepElimSndStrict
    , EvalStep stepPair1
    , EvalValueStep stepPair2
    ]
    [] [] []

inferTmPair :: (Monad m, AsTyPair ty, AsTmPair tm) => (tm a -> m (ty a)) -> tm a -> Maybe (m (ty a))
inferTmPair inferFn tm = do
  (tm1, tm2) <- preview _TmPair tm
  return $ do
    ty1 <- inferFn tm1
    ty2 <- inferFn tm2
    return $ review _TyPair (ty1, ty2)

inferTmFst :: (MonadError e m, AsExpectedTyPair e (ty a), AsTyPair ty, AsTmPair tm) => (tm a -> m (ty a)) -> tm a -> Maybe (m (ty a))
inferTmFst inferFn tm = do
  tmP <- preview _TmFst tm
  return $ do
    tyP <- inferFn tmP
    (ty1, _) <- expectTyPair tyP
    return ty1

inferTmSnd :: (MonadError e m, AsExpectedTyPair e (ty a), AsTyPair ty, AsTmPair tm) => (tm a -> m (ty a)) -> tm a -> Maybe (m (ty a))
inferTmSnd inferFn tm = do
  tmP <- preview _TmFst tm
  return $ do
    tyP <- inferFn tmP
    (_, ty2) <- expectTyPair tyP
    return ty2

inferRules :: (MonadError e m, AsExpectedTyPair e (ty a), AsTyPair ty, AsTmPair tm) => FragmentInput e s r m ty p tm a
inferRules =
  FragmentInput
    [] []
    [ InferRecurse inferTmPair
    , InferRecurse inferTmFst
    , InferRecurse inferTmSnd
    ]
    [] []

matchPair :: (AsPtPair p, AsTmPair tm) => (p a -> tm a -> Maybe [tm a]) -> p a -> tm a -> Maybe [tm a]
matchPair matchFn p tm = do
  (p1, p2) <- preview _PtPair p
  (tm1, tm2) <- preview _TmPair tm
  tms1 <- matchFn p1 tm1
  tms2 <- matchFn p2 tm2
  return $ tms1 ++ tms2

checkPair :: (MonadError e m, AsExpectedTyPair e (ty a), AsTyPair ty, AsPtPair p) => (p a -> ty a -> m [ty a]) -> p a -> ty a -> Maybe (m [ty a])
checkPair checkFn p ty = do
  (p1, p2) <- preview _PtPair p
  return $ do
    (ty1, ty2) <- expectTyPair ty
    mappend <$> checkFn p1 ty1 <*> checkFn p2 ty2

patternRules :: (MonadError e m, AsExpectedTyPair e (ty a), AsTyPair ty, AsPtPair p, AsTmPair tm) => FragmentInput e s r m ty p tm a
patternRules =
  FragmentInput
    [] [] []
    [ PMatchRecurse matchPair ]
    [ PCheckRecurse checkPair ]

type PairContext e s r m ty p tm a = (MonadError e m, AsExpectedTyPair e (ty a), AsTyPair ty, AsPtPair p, AsTmPair tm)

pairFragmentLazy :: PairContext e s r m ty p tm a
             => FragmentInput e s r m ty p tm a
pairFragmentLazy =
  evalRulesLazy `mappend` inferRules `mappend` patternRules

pairFragmentStrict :: PairContext e s r m ty p tm a
             => FragmentInput e s r m ty p tm a
pairFragmentStrict =
  evalRulesStrict `mappend` inferRules `mappend` patternRules

-- Helpers

tyPair :: AsTyPair ty => ty a -> ty a -> ty a
tyPair = curry $ review _TyPair

ptPair :: AsPtPair p => p a -> p a -> p a
ptPair = curry $ review _PtPair

tmPair :: AsTmPair tm => tm a -> tm a -> tm a
tmPair = curry $ review _TmPair

tmFst :: AsTmPair tm => tm a -> tm a
tmFst = review _TmFst

tmSnd :: AsTmPair tm => tm a -> tm a
tmSnd = review _TmSnd