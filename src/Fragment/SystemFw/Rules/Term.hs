{-|
Copyright   : (c) Dave Laing, 2017
License     : BSD3
Maintainer  : dave.laing.80@gmail.com
Stability   : experimental
Portability : non-portable
-}
{-# LANGUAGE ConstraintKinds #-}
module Fragment.SystemFw.Rules.Term (
    SystemFwTermContext
  , systemFwTermRules
  ) where

import Bound (Bound, instantiate1)
import Control.Lens (review, preview)
import Control.Lens.Wrapped (_Wrapped, _Unwrapped)

import Rules.Term
import Ast.Term

import Fragment.SystemFw.Ast.Term

valTmLam :: AsTmSystemFw ki ty pt tm => Term ki ty pt tm a -> Maybe (Term ki ty pt tm a)
valTmLam tm = do
  _ <- preview _TmLam tm
  return  tm

valTmLamTy :: AsTmSystemFw ki ty pt tm => Term ki ty pt tm a -> Maybe (Term ki ty pt tm a)
valTmLamTy tm = do
  _ <- preview _TmLamTy tm
  return  tm

stepTmApp1 :: AsTmSystemFw ki ty pt tm => (Term ki ty pt tm a -> Maybe (Term ki ty pt tm a)) -> Term ki ty pt tm a -> Maybe (Term ki ty pt tm a)
stepTmApp1 evalFn tm = do
  (f, x) <- preview _TmApp tm
  f' <- evalFn f
  return $ review _TmApp (f', x)

stepTmAppTy1 :: AsTmSystemFw ki ty pt tm => (Term ki ty pt tm a -> Maybe (Term ki ty pt tm a)) -> Term ki ty pt tm a -> Maybe (Term ki ty pt tm a)
stepTmAppTy1 evalFn tm = do
  (f, x) <- preview _TmAppTy tm
  f' <- evalFn f
  return $ review _TmAppTy (f', x)

stepTmLamAppLazy :: (AstBound ki ty pt tm, AsTmSystemFw ki ty pt tm) => Term ki ty pt tm a -> Maybe (Term ki ty pt tm a)
stepTmLamAppLazy tm = do
  (tmF, tmX) <- preview _TmApp tm
  (_, s) <- preview _TmLam tmF
  return . review _Wrapped . instantiate1 (review _Unwrapped tmX) $ s

stepTmLamAppStrict :: (AstBound ki ty pt tm, AsTmSystemFw ki ty pt tm) => (Term ki ty pt tm a -> Maybe (Term ki ty pt tm a)) -> Term ki ty pt tm a -> Maybe (Term ki ty pt tm a)
stepTmLamAppStrict valueFn tm = do
  (tmF, tmX) <- preview _TmApp tm
  (_, s) <- preview _TmLam tmF
  vX <- valueFn tmX
  return . review _Wrapped . instantiate1 (review _Unwrapped vX) $ s

stepTmLamTyAppTy :: (Bound (ty ki), Bound pt, Bound (tm ki ty pt)) => AsTmSystemFw ki ty pt tm => Term ki ty pt tm a -> Maybe (Term ki ty pt tm a)
stepTmLamTyAppTy tm = do
  (tmF, tyX) <- preview _TmAppTy tm
  (_, s) <- preview _TmLamTy tmF
  return . review _Wrapped . instantiate1 (review _Type tyX) $ s

stepTmApp2 :: AsTmSystemFw ki ty pt tm => (Term ki ty pt tm a -> Maybe (Term ki ty pt tm a)) -> (Term ki ty pt tm a -> Maybe (Term ki ty pt tm a)) -> Term ki ty pt tm a -> Maybe (Term ki ty pt tm a)
stepTmApp2 valueFn stepFn tm = do
  (tmF, tmX) <- preview _TmApp tm
  vF <- valueFn tmF
  tmX' <- stepFn tmX
  return $ review _TmApp (vF, tmX')

type SystemFwTermContext ki ty pt tm a = (TermContext ki ty pt tm a, AsTmSystemFw ki ty pt tm)

systemFwEvalRulesStrict :: SystemFwTermContext ki ty pt tm a
                       => EvalInput ki ty pt tm a
systemFwEvalRulesStrict =
  EvalInput
  [ ValueBase valTmLam
  , ValueBase valTmLamTy
  ]
  [ EvalStep stepTmApp1
  , EvalStep stepTmAppTy1
  , EvalValue stepTmLamAppStrict
  , EvalBase stepTmLamTyAppTy
  , EvalValueStep stepTmApp2
  ]
  []

systemFwEvalRulesLazy :: SystemFwTermContext ki ty pt tm a
                  => EvalInput ki ty pt tm a
systemFwEvalRulesLazy =
  EvalInput
  [ ValueBase valTmLam
  , ValueBase valTmLamTy
  ]
  [ EvalStep stepTmApp1
  , EvalStep stepTmAppTy1
  , EvalBase stepTmLamAppLazy
  , EvalBase stepTmLamTyAppTy
  ]
  []

systemFwTermRules :: SystemFwTermContext ki ty pt tm a
                 => TermInput ki ty pt tm a
systemFwTermRules =
  TermInput systemFwEvalRulesStrict systemFwEvalRulesLazy