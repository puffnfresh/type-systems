{-|
Copyright   : (c) Dave Laing, 2017
License     : BSD3
Maintainer  : dave.laing.80@gmail.com
Stability   : experimental
Portability : non-portable
-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeFamilies #-}
module Fragment.HM.Rules (
    RHM
  ) where

import GHC.Exts (Constraint)

import Rules
import Rules.Unification
import Ast.Type

import Fragment.HM.Ast
import Fragment.HM.Rules.Kind.Infer.SyntaxDirected
import Fragment.HM.Rules.Type.Infer.Offline
import Fragment.HM.Rules.Type
import Fragment.HM.Rules.Term

data RHM

instance RulesIn RHM where
  type InferKindContextSyntax e w s r m ki ty a RHM = HMInferKindContext e w s r m ki ty a
  type InferTypeContextSyntax e w s r m ki ty pt tm a RHM = (() :: Constraint)
  type InferTypeContextOffline e w s r m ki ty pt tm a RHM = HMInferTypeContext e w s r m ki ty pt tm a
  type RuleTypeContext ki ty a RHM = HMTypeContext ki ty a
  type RuleTermContext ki ty pt tm a RHM = HMTermContext ki ty pt tm a
  type KindList RHM = '[]
  type TypeList RHM = '[TyFHM]
  type ErrorList ki ty pt tm a RHM = '[ErrExpectedTyArr ki ty a, ErrOccursError (Type ki ty) a, ErrUnificationMismatch (Type ki ty) a, ErrUnificationExpectedEq (Type ki ty) a]
  type WarningList ki ty pt tm a RHM = '[]
  type PatternList RHM = '[]
  type TermList RHM = '[TmFHM]

  inferKindInputSyntax _ = hmInferKindRules
  inferTypeInputSyntax _ = mempty
  inferTypeInputOffline _ = hmInferTypeRules
  typeInput _ = hmTypeRules
  termInput _ = hmTermRules
