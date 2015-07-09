{-# LANGUAGE MultiParamTypeClasses                    #-}
{-# LANGUAGE ScopedTypeVariables                      #-}
{-# LANGUAGE OverloadedStrings                        #-}

{-# OPTIONS -fno-warn-orphans #-}

module Thentos.Adhocracy3.Backend.Api.Docs.Simple where

import Control.Applicative (pure, (<$>), (<*>))
import Data.Proxy (Proxy(Proxy))
import Servant.Docs (ToSample(toSample))

import qualified Servant.Docs as Docs

import Thentos.Backend.Api.Docs.Common ()
import Thentos.Backend.Api.Docs.Proxy ()
import Thentos.Types

import qualified Thentos.Adhocracy3.Backend.Api.Simple as Adhocracy3


instance ToSample Adhocracy3.A3UserNoPass Adhocracy3.A3UserNoPass where
    toSample _ = Adhocracy3.A3UserNoPass <$> toSample (Proxy :: Proxy UserFormData)

instance ToSample Adhocracy3.A3UserWithPass Adhocracy3.A3UserWithPass where
    toSample _ = Adhocracy3.A3UserWithPass <$> toSample (Proxy :: Proxy UserFormData)

instance ToSample a a => ToSample (Adhocracy3.A3Resource a) (Adhocracy3.A3Resource a) where
    toSample _ = Adhocracy3.A3Resource
                    <$> (Just <$> toSample (Proxy :: Proxy Adhocracy3.Path))
                    <*> (Just <$> toSample (Proxy :: Proxy Adhocracy3.ContentType))
                    <*> (Just <$> toSample (Proxy :: Proxy a))

instance ToSample Adhocracy3.Path Adhocracy3.Path where
    toSample _ = pure $ Adhocracy3.Path "/proposals/environment"

instance ToSample Adhocracy3.ActivationRequest Adhocracy3.ActivationRequest where
    toSample _ = Adhocracy3.ActivationRequest <$> toSample (Proxy :: Proxy Adhocracy3.Path)

-- FIXME: split up LoginRequest into two separate types for login by email
-- and login by user name, in order to provide a correct example for
-- login_email request body
instance ToSample Adhocracy3.LoginRequest Adhocracy3.LoginRequest where
    toSample _ = Adhocracy3.LoginByName <$> toSample (Proxy :: Proxy UserName)
                                        <*> toSample (Proxy :: Proxy UserPass)

instance ToSample Adhocracy3.RequestResult Adhocracy3.RequestResult where
    toSample _ = Adhocracy3.RequestSuccess
                    <$> toSample (Proxy :: Proxy Adhocracy3.Path)
                    <*> toSample (Proxy :: Proxy ThentosSessionToken)

instance ToSample Adhocracy3.ContentType Adhocracy3.ContentType where
    toSample _ = pure Adhocracy3.CTUser

docs :: Docs.API
docs = Docs.docs (Proxy :: Proxy Adhocracy3.Api)
