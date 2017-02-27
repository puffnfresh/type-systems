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
module Fragment.Tuple.Rules (
    RTuple
  ) where

import Rules

import Fragment.Tuple.Ast
import Fragment.Tuple.Rules.Infer
import Fragment.Tuple.Rules.Eval

data RTuple

instance RulesIn RTuple where
  type RuleInferContext e w s r m ty pt tm a RTuple = TupleInferContext e w s r m ty pt tm a
  type RuleEvalContext ty pt tm a RTuple = TupleEvalContext ty pt tm a
  type TypeList RTuple = '[TyFTuple]
  type ErrorList ty pt tm a RTuple = '[ErrExpectedTyTuple ty a, ErrTupleOutOfBounds]
  type WarningList ty pt tm a RTuple = '[]
  type PatternList RTuple = '[PtFTuple]
  type TermList RTuple = '[TmFTuple]

  inferInput _ = tupleInferRules
  evalLazyInput _ = tupleEvalRulesLazy
  evalStrictInput _ = tupleEvalRulesStrict