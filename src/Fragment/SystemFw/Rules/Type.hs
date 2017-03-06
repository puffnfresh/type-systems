{-|
Copyright   : (c) Dave Laing, 2017
License     : BSD3
Maintainer  : dave.laing.80@gmail.com
Stability   : experimental
Portability : non-portable
-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE RankNTypes #-}
module Fragment.SystemFw.Rules.Type (
    SystemFwTypeContext
  , systemFwTypeRules
  ) where

import Bound (toScope, fromScope)
import Control.Lens (review, preview)

import Rules.Type
import Ast.Type

import Fragment.SystemFw.Ast.Type

type SystemFwTypeContext ki ty a = AsTySystemFw ki ty

normalizeArr :: SystemFwTypeContext ki ty a
             => (Type ki ty a -> Type ki ty a)
             -> Type ki ty a
             -> Maybe (Type ki ty a)
normalizeArr normalizeFn ty = do
  (ty1, ty2) <- preview _TyArr ty
  return $ review _TyArr (normalizeFn ty1, normalizeFn ty2)

normalizeAll :: SystemFwTypeContext ki ty a
             => (forall b. Type ki ty b -> Type ki ty b)
             -> Type ki ty a
             -> Maybe (Type ki ty a)
normalizeAll normalizeFn ty = do
  (k, s) <- preview _TyAll ty
  return $ review _TyAll (k, toScope . normalizeFn . fromScope $ s)

normalizeLam :: SystemFwTypeContext ki ty a
             => (forall b. Type ki ty b -> Type ki ty b)
             -> Type ki ty a
             -> Maybe (Type ki ty a)
normalizeLam normalizeFn ty = do
  (k, s) <- preview _TyLam ty
  return $ review _TyLam (k, toScope . normalizeFn . fromScope $ s)

normalizeApp :: SystemFwTypeContext ki ty a
             => (Type ki ty a -> Type ki ty a)
             -> Type ki ty a
             -> Maybe (Type ki ty a)
normalizeApp normalizeFn ty = do
  (ty1, ty2) <- preview _TyApp ty
  return $ review _TyApp (normalizeFn ty1, normalizeFn ty2)


systemFwTypeRules :: SystemFwTypeContext ki ty a
              => TypeInput ki ty a
systemFwTypeRules =
  TypeInput
    [ NormalizeTypeRecurse normalizeArr
    , NormalizeTypeRecurse normalizeAll
    , NormalizeTypeRecurse normalizeLam
    , NormalizeTypeRecurse normalizeApp
    ]