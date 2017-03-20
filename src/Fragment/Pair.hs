{-|
Copyright   : (c) Dave Laing, 2017
License     : BSD3
Maintainer  : dave.laing.80@gmail.com
Stability   : experimental
Portability : non-portable
-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FlexibleInstances #-}
module Fragment.Pair (
    module X
  , PairTag
  ) where

import Ast
import Rules.Term
import Fragment.KiBase.Ast.Kind

import Fragment.Pair.Ast as X
import Fragment.Pair.Rules as X
import Fragment.Pair.Helpers as X

import Fragment.Pair.Rules.Term

data PairTag

instance AstIn PairTag where
  type KindList PairTag = '[KiFBase]
  type TypeList PairTag = '[TyFPair]
  type PatternList PairTag = '[PtFPair]
  type TermList PairTag = '[TmFPair]

instance EvalRules EStrict PairTag where
  type EvalConstraint ki ty pt tm a EStrict PairTag =
    PairEvalConstraint ki ty pt tm a

  evalInput _ _ =
    pairEvalRulesStrict

instance EvalRules ELazy PairTag where
  type EvalConstraint ki ty pt tm a ELazy PairTag =
    PairEvalConstraint ki ty pt tm a

  evalInput _ _ =
    pairEvalRulesLazy
