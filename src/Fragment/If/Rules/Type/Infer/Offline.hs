{-|
Copyright   : (c) Dave Laing, 2017
License     : BSD3
Maintainer  : dave.laing.80@gmail.com
Stability   : experimental
Portability : non-portable
-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE FlexibleContexts #-}
module Fragment.If.Rules.Type.Infer.Offline (
    IfInferContext
  , ifInferRules
  ) where

import Control.Monad.Except (MonadError)
import Control.Lens (review, preview)

import Rules.Type.Infer.Offline
import Ast.Type
import Ast.Term
import Ast.Error.Common
import Data.Functor.Rec

import Fragment.Bool.Ast.Type
import Fragment.If.Ast.Term

inferTmIf :: (Eq a, EqRec (ty ki), MonadError e m, AsUnexpectedType e ki ty a, AsExpectedTypeEq e ki ty a, AsTyBool ki ty, AsTmIf ki ty pt tm)
          => (Term ki ty pt tm a -> UnifyT ki ty a m (Type ki ty a))
          -> Term ki ty pt tm a
          -> Maybe (UnifyT ki ty a m (Type ki ty a))
inferTmIf inferFn tm = do
  (tmB, tmT, tmF) <- preview _TmIf tm
  return $ do
    tyB <- inferFn tmB
    expectType (ExpectedType tyB) (ActualType (review _TyBool ()))
    tyT <- inferFn tmT
    tyF <- inferFn tmF
    expectTypeEq tyT tyF
    return tyT

type IfInferContext e w s r m ki ty pt tm a = (InferContext e w s r m ki ty pt tm a, AsUnexpectedType e ki ty a, AsExpectedTypeEq e ki ty a, AsTyBool ki ty, AsTmIf ki ty pt tm)

ifInferRules :: IfInferContext e w s r m ki ty pt tm a
             => InferInput e w s r m ki ty pt tm a
ifInferRules =
  InferInput [] [] [ InferRecurse inferTmIf ] []