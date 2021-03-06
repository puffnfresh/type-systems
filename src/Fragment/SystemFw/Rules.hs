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
module Fragment.SystemFw.Rules (
    RSystemFw
  ) where

import GHC.Exts (Constraint)

import Ast
import Ast.Error.Common
import Context.Type.Error
import Rules

import Fragment.SystemFw.Ast
import Fragment.SystemFw.Rules.Kind.Infer.SyntaxDirected
import Fragment.SystemFw.Rules.Type.Infer.SyntaxDirected

data RSystemFw

instance AstIn RSystemFw where
  type KindList RSystemFw = '[KiFSystemFw]
  type TypeList RSystemFw = '[TyFSystemFw]
  type PatternList RSystemFw = '[]
  type TermList RSystemFw = '[TmFSystemFw]

instance RulesIn RSystemFw where
  type InferKindContextSyntax e w s r m ki ty a RSystemFw = SystemFwInferKindContext e w s r m ki ty a
  type InferTypeContextSyntax e w s r m ki ty pt tm a RSystemFw = SystemFwInferTypeContext e w s r m ki ty pt tm a
  type InferTypeContextOffline e w s r m ki ty pt tm a RSystemFw = (() :: Constraint)
  type ErrorList ki ty pt tm a RSystemFw = '[ErrUnexpectedKind ki, ErrExpectedKiArr ki, ErrExpectedKindEq ki, ErrExpectedTyArr ki ty a, ErrExpectedTyAll ki ty a, ErrUnboundTypeVariable a]
  type WarningList ki ty pt tm a RSystemFw = '[]

  inferKindInputSyntax _ = systemFwInferKindRules
  inferTypeInputSyntax _ = systemFwInferTypeRules
  inferTypeInputOffline _ = mempty
