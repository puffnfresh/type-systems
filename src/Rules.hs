{-|
Copyright   : (c) Dave Laing, 2017
License     : BSD3
Maintainer  : dave.laing.80@gmail.com
Stability   : experimental
Portability : non-portable
-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE InstanceSigs #-}
module Rules (
    RulesIn(..)
  , RulesOut(..)
  ) where

import Data.Proxy
import GHC.Exts (Constraint)

import Control.Monad.Trans (lift)

import Rules.Unification
import qualified Rules.Kind.Infer.SyntaxDirected as KSD
import qualified Rules.Type.Infer.SyntaxDirected as TSD
import qualified Rules.Type.Infer.Offline as TUO
import Util.TypeList

import Ast
import Ast.Type
import Ast.Error
import Ast.Error.Common
import Ast.Warning

class AstIn k => RulesIn (k :: j) where
  type InferKindContextSyntax e w s r (m :: * -> *) (ki :: * -> *) (ty :: (* -> *) -> (* -> *) -> * -> *) a k :: Constraint
  type InferTypeContextSyntax e w s r (m :: * -> *) (ki :: * -> *) (ty :: (* -> *) -> (* -> *) -> * -> *) (pt :: (* -> *) -> * -> *) (tm :: ((* -> *) -> ((* -> *) -> (* -> *) -> * -> *) -> ((* -> *) -> * -> *) -> (* -> *) -> * -> *)) a k :: Constraint
  type InferTypeContextOffline e w s r (m :: * -> *) (ki :: * -> *) (ty :: (* -> *) -> (* -> *) -> * -> *) (pt :: (* -> *) -> * -> *) (tm :: ((* -> *) -> ((* -> *) -> (* -> *) -> * -> *) -> ((* -> *) -> * -> *) -> (* -> *) -> * -> *)) a k :: Constraint

  type ErrorList (ki :: * -> *) (ty :: (* -> *) -> (* -> *) -> * -> *) (pt :: (* -> *) -> * -> *) (tm :: ((* -> *) -> ((* -> *) -> (* -> *) -> * -> *) -> ((* -> *) -> * -> *) -> (* -> *) -> * -> *)) a k :: [*]
  type WarningList (ki :: * -> *) (ty :: (* -> *) -> (* -> *) -> * -> *) (pt :: (* -> *) -> * -> *) (tm :: ((* -> *) -> ((* -> *) -> (* -> *) -> * -> *) -> ((* -> *) -> * -> *) -> (* -> *) -> * -> *)) a k :: [*]

  inferKindInputSyntax :: InferKindContextSyntax e w s r m ki ty a k
                       => Proxy k
                       -> KSD.InferKindInput e w s r m ki ty a
  inferTypeInputSyntax :: ( InferTypeContextSyntax e w s r m ki ty pt tm a k
                      , InferKindContextSyntax e w s r m ki ty a k
                      )
                   => Proxy k
                   -> TSD.InferTypeInput e w s r m m ki ty pt tm a
  inferTypeInputOffline :: InferTypeContextOffline e w s r m ki ty pt tm a k
                    => Proxy k
                    -> TUO.InferTypeInput e w s r m (TUO.UnifyT ki ty a m) ki ty pt tm a

instance RulesIn '[] where
  type InferKindContextSyntax e w s r m ki ty a '[] =
    KSD.InferKindContext e w s r m ki ty a
  type InferTypeContextSyntax e w s r m ki ty pt tm a '[] =
    TSD.InferTypeContext e w s r m ki ty pt tm a
  type InferTypeContextOffline e w s r m ki ty pt tm a '[] =
    TUO.InferTypeContext e w s r m ki ty pt tm a
  type ErrorList ki ty pt tm a '[] = '[ErrUnknownKindError, ErrUnknownTypeError, ErrOccursError (Type ki ty) a, ErrUnificationMismatch (Type ki ty) a, ErrUnificationExpectedEq (Type ki ty) a]
  type WarningList ki ty pt tm a '[] = '[]

  inferKindInputSyntax _ = mempty
  inferTypeInputSyntax _ = mempty
  inferTypeInputOffline _ = mempty

instance (RulesIn k, RulesIn ks) => RulesIn (k ': ks) where
  type InferKindContextSyntax e w s r m ki ty a (k ': ks) = (InferKindContextSyntax e w s r m ki ty a k, InferKindContextSyntax e w s r m ki ty a ks)
  type InferTypeContextSyntax e w s r m ki ty pt tm a (k ': ks) = (InferTypeContextSyntax e w s r m ki ty pt tm a k, InferTypeContextSyntax e w s r m ki ty pt tm a ks)
  type InferTypeContextOffline e w s r m ki ty pt tm a (k ': ks) = (InferTypeContextOffline e w s r m ki ty pt tm a k, InferTypeContextOffline e w s r m ki ty pt tm a ks)
  type ErrorList ki ty pt tm a (k ': ks) = Append (ErrorList ki ty pt tm a k) (ErrorList ki ty pt tm a ks)
  type WarningList ki ty pt tm a (k ': ks) = Append (WarningList ki ty pt tm a k) (WarningList ki ty pt tm a ks)

  inferKindInputSyntax _ = inferKindInputSyntax (Proxy :: Proxy k) `mappend` inferKindInputSyntax (Proxy :: Proxy ks)
  inferTypeInputSyntax _ = inferTypeInputSyntax (Proxy :: Proxy k) `mappend` inferTypeInputSyntax (Proxy :: Proxy ks)
  inferTypeInputOffline _ = inferTypeInputOffline (Proxy :: Proxy k) `mappend` inferTypeInputOffline (Proxy :: Proxy ks)

class AstOut k => RulesOut (k :: j) where

  type RError (ki :: * -> *) (ty :: (* -> *) -> (* -> *) -> * -> *) (pt :: (* -> *) -> * -> *) (tm :: ((* -> *) -> ((* -> *) -> (* -> *) -> * -> *) -> ((* -> *) -> * -> *) -> (* -> *) -> * -> *)) a k :: *
  type RWarning (ki :: * -> *) (ty :: (* -> *) -> (* -> *) -> * -> *) (pt :: (* -> *) -> * -> *) (tm :: ((* -> *) -> ((* -> *) -> (* -> *) -> * -> *) -> ((* -> *) -> * -> *) -> (* -> *) -> * -> *)) a k :: *

  inferKindOutputSyntax :: ( KSD.InferKindContext e w s r m ki ty a
                           , InferKindContextSyntax e w s r m ki ty a k
                           )
                        => Proxy k
                        -> KSD.InferKindOutput e w s r m ki ty a
  inferTypeOutputSyntax :: ( TSD.InferTypeContext e w s r m ki ty pt tm a
                       , InferTypeContextSyntax e w s r m ki ty pt tm a k
                       , KSD.InferKindContext e w s r m ki ty a
                       , InferKindContextSyntax e w s r m ki ty a k
                       )
                    => Proxy k
                    -> (Type ki ty a -> Type ki ty a)
                    -> TSD.InferTypeOutput e w s r m ki ty pt tm a
  inferTypeOutputOffline :: ( TUO.InferTypeContext e w s r m ki ty pt tm a
                        , InferTypeContextOffline e w s r m ki ty pt tm a k
                        , KSD.InferKindContext e w s r m ki ty a
                        , InferKindContextSyntax e w s r m ki ty a k
                        )
                     => Proxy k
                     -> (Type ki ty a -> Type ki ty a)
                     -> TUO.InferTypeOutput e w s r m ki ty pt tm a

instance RulesIn k => RulesOut (k :: j) where

  type RError ki ty pt tm a k = ErrSum (ErrorList ki ty pt tm a k)
  type RWarning ki ty pt tm a k = WarnSum (WarningList ki ty pt tm a k)

  inferKindOutputSyntax =
    KSD.prepareInferKind . inferKindInputSyntax

  inferTypeOutputSyntax :: forall e w s r m ki ty pt tm a.
                       ( TSD.InferTypeContext e w s r m ki ty pt tm a
                       , InferTypeContextSyntax e w s r m ki ty pt tm a k
                       , KSD.InferKindContext e w s r m ki ty a
                       , InferKindContextSyntax e w s r m ki ty a k
                       )
                    => Proxy k
                    -> (Type ki ty a -> Type ki ty a)
                    -> TSD.InferTypeOutput e w s r m ki ty pt tm a
  inferTypeOutputSyntax p normalize =
     let
       ikos :: ( KSD.InferKindContext e w s r m ki ty a
               , InferKindContextSyntax e w s r m ki ty a k
               )
            => KSD.InferKindOutput e w s r m ki ty a
       ikos = inferKindOutputSyntax p
       inferKind = KSD.kroInfer ikos
     in
       TSD.prepareInferType inferKind normalize .
       inferTypeInputSyntax $ p

  inferTypeOutputOffline :: forall e w s r m ki ty pt tm a.
                       ( TUO.InferTypeContext e w s r m ki ty pt tm a
                       , InferTypeContextOffline e w s r m ki ty pt tm a k
                       , KSD.InferKindContext e w s r m ki ty a
                       , InferKindContextSyntax e w s r m ki ty a k
                       )
                    => Proxy k
                    -> (Type ki ty a -> Type ki ty a)
                    -> TUO.InferTypeOutput e w s r m ki ty pt tm a
  inferTypeOutputOffline p normalize =
     let
       ikos :: ( KSD.InferKindContext e w s r m ki ty a
               , InferKindContextSyntax e w s r m ki ty a k
               )
            => KSD.InferKindOutput e w s r m ki ty a
       ikos = inferKindOutputSyntax p
       inferKind = KSD.kroInfer ikos
     in
       TUO.prepareInferType (lift . inferKind) normalize .
       inferTypeInputOffline $ p
