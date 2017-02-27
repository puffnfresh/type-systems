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
module Fragment.PtVar.Rules (
    RPtVar
  ) where

import Rules

import Fragment.PtVar.Rules.Infer
import Fragment.PtVar.Rules.Eval

data RPtVar

instance RulesIn RPtVar where
  type RuleInferContext e w s r m ty pt tm a RPtVar = PtVarInferContext e w s r m ty pt tm a
  type RuleEvalContext ty pt tm a RPtVar = PtVarEvalContext ty pt tm a
  type TypeList RPtVar = '[]
  type ErrorList ty pt tm a RPtVar = '[]
  type WarningList ty pt tm a RPtVar = '[]
  type PatternList RPtVar = '[]
  type TermList RPtVar = '[]

  inferInput _ = ptVarInferRules
  evalLazyInput _ = ptVarEvalRules
  evalStrictInput _ = ptVarEvalRules