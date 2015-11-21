{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}

{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveTraversable #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE TemplateHaskell #-}
module Data.Swagger.Internal where

import           Control.Applicative
import           Control.Monad
import           Data.Aeson
import           Data.Aeson.TH            (deriveJSON)
import           Data.Foldable            (Foldable)
import           Data.HashMap.Strict      (HashMap)
import qualified Data.HashMap.Strict      as HashMap
import           Data.Map                 (Map)
import qualified Data.Map                 as Map
import           Data.Monoid
import           Data.String              (fromString)
import           Data.Text                (Text)
import qualified Data.Text                as Text
import           Data.Traversable         (Traversable)
import           Data.Type.Equality
import           Data.Hashable            (Hashable)
import           GHC.Generics             (Generic)
import           Network                  (HostName, PortNumber)
import           Network.HTTP.Media       (MediaType)
import           Text.Read                (readMaybe)

import Data.Swagger.Internal.Utils

-- | This is the root document object for the API specification.
data Swagger = Swagger
  { -- | Provides metadata about the API.
    -- The metadata can be used by the clients if needed.
    _info :: Info

    -- | The host (name or ip) serving the API. It MAY include a port.
    -- If the host is not included, the host serving the documentation is to be used (including the port).
  , _host :: Maybe Host

    -- | The base path on which the API is served, which is relative to the host.
    -- If it is not included, the API is served directly under the host.
    -- The value MUST start with a leading slash (/).
  , _basePath :: Maybe FilePath

    -- | The transfer protocol of the API.
    -- If the schemes is not included, the default scheme to be used is the one used to access the Swagger definition itself.
  , _schemes :: Maybe [Scheme]

    -- | A list of MIME types the APIs can consume.
    -- This is global to all APIs but can be overridden on specific API calls.
  , _consumes :: MimeList

    -- | A list of MIME types the APIs can produce.
    -- This is global to all APIs but can be overridden on specific API calls. 
  , _produces :: MimeList

    -- | The available paths and operations for the API.
  , _paths :: Paths

    -- | An object to hold data types produced and consumed by operations.
  , _definitions :: HashMap Text SomeSchema

    -- | An object to hold parameters that can be used across operations.
    -- This property does not define global parameters for all operations.
  , _parameters :: HashMap Text Parameter

    -- | An object to hold responses that can be used across operations.
    -- This property does not define global responses for all operations.
  , _responses :: HashMap Text Response

    -- | Security scheme definitions that can be used across the specification.
  , _securityDefinitions :: HashMap Text SecurityScheme

    -- | A declaration of which security schemes are applied for the API as a whole.
    -- The list of values describes alternative security schemes that can be used
    -- (that is, there is a logical OR between the security requirements).
    -- Individual operations can override this definition.
  , _security :: [SecurityRequirement]

    -- | A list of tags used by the specification with additional metadata.
    -- The order of the tags can be used to reflect on their order by the parsing tools.
    -- Not all tags that are used by the Operation Object must be declared.
    -- The tags that are not declared may be organized randomly or based on the tools' logic.
    -- Each tag name in the list MUST be unique.
  , _tags :: [Tag]

    -- | Additional external documentation.
  , _externalDocs :: Maybe ExternalDocs
  } deriving (Eq, Show, Generic)

-- | The object provides metadata about the API.
-- The metadata can be used by the clients if needed,
-- and can be presented in the Swagger-UI for convenience.
data Info = Info
  { -- | The title of the application.
    _infoTitle :: Text

    -- | A short description of the application.
    -- GFM syntax can be used for rich text representation.
  , _infoDescription :: Maybe Text

    -- | The Terms of Service for the API.
  , _infoTermsOfService :: Maybe Text

    -- | The contact information for the exposed API.
  , _infoContact :: Maybe Contact

    -- | The license information for the exposed API.
  , _infoLicense :: Maybe License

    -- | Provides the version of the application API
    -- (not to be confused with the specification version).
  , _infoVersion :: Text
  } deriving (Eq, Show, Generic)

-- | Contact information for the exposed API.
data Contact = Contact
  { -- | The identifying name of the contact person/organization.
    _contactName  :: Maybe Text

    -- | The URL pointing to the contact information.
  , _contactUrl   :: Maybe URL

    -- | The email address of the contact person/organization.
  , _contactEmail :: Maybe Text
  } deriving (Eq, Show)

-- | License information for the exposed API.
data License = License
  { -- | The license name used for the API.
    _licenseName :: Text

    -- | A URL to the license used for the API.
  , _licenseUrl :: Maybe URL
  } deriving (Eq, Show)

-- | The host (name or ip) serving the API. It MAY include a port.
data Host = Host
  { _hostName :: HostName         -- ^ Host name.
  , _hostPort :: Maybe PortNumber -- ^ Optional port.
  } deriving (Eq, Show)

-- | The transfer protocol of the API.
data Scheme
  = Http
  | Https
  | Ws
  | Wss
  deriving (Eq, Show)

-- | The available paths and operations for the API.
data Paths = Paths
  { -- | Holds the relative paths to the individual endpoints.
    -- The path is appended to the @'basePath'@ in order to construct the full URL.
    _pathsMap         :: HashMap FilePath PathItem
  } deriving (Eq, Show, Generic)

-- | Describes the operations available on a single path.
-- A @'PathItem'@ may be empty, due to ACL constraints.
-- The path itself is still exposed to the documentation viewer
-- but they will not know which operations and parameters are available.
data PathItem = PathItem
  { -- | A definition of a GET operation on this path.
    _pathItemGet :: Maybe Operation

    -- | A definition of a PUT operation on this path.
  , _pathItemPut :: Maybe Operation

    -- | A definition of a POST operation on this path.
  , _pathItemPost :: Maybe Operation

    -- | A definition of a DELETE operation on this path.
  , _pathItemDelete :: Maybe Operation

    -- | A definition of a OPTIONS operation on this path.
  , _pathItemOptions :: Maybe Operation

    -- | A definition of a HEAD operation on this path.
  , _pathItemHead :: Maybe Operation

    -- | A definition of a PATCH operation on this path.
  , _pathItemPatch :: Maybe Operation

    -- | A list of parameters that are applicable for all the operations described under this path.
    -- These parameters can be overridden at the operation level, but cannot be removed there.
    -- The list MUST NOT include duplicated parameters.
    -- A unique parameter is defined by a combination of a name and location.
  , _pathItemParameters :: [Referenced Parameter]
  } deriving (Eq, Show, Generic)

-- | Describes a single API operation on a path.
data Operation = Operation
  { -- | A list of tags for API documentation control.
    -- Tags can be used for logical grouping of operations by resources or any other qualifier.
    _operationTags :: [Text]

    -- | A short summary of what the operation does.
    -- For maximum readability in the swagger-ui, this field SHOULD be less than 120 characters.
  , _operationSummary :: Maybe Text

    -- | A verbose explanation of the operation behavior.
    -- GFM syntax can be used for rich text representation.
  , _operationDescription :: Maybe Text

    -- | Additional external documentation for this operation.
  , _operationExternalDocs :: Maybe ExternalDocs

    -- | Unique string used to identify the operation.
    -- The id MUST be unique among all operations described in the API.
    -- Tools and libraries MAY use the it to uniquely identify an operation,
    -- therefore, it is recommended to follow common programming naming conventions.
  , _operationOperationId :: Maybe Text

    -- | A list of MIME types the operation can consume.
    -- This overrides the @'consumes'@.
    -- @Just []@ MAY be used to clear the global definition.
  , _operationConsumes :: Maybe MimeList

    -- | A list of MIME types the operation can produce.
    -- This overrides the @'produces'@.
    -- @Just []@ MAY be used to clear the global definition.
  , _operationProduces :: Maybe MimeList

    -- | A list of parameters that are applicable for this operation.
    -- If a parameter is already defined at the @'PathItem'@,
    -- the new definition will override it, but can never remove it.
    -- The list MUST NOT include duplicated parameters.
    -- A unique parameter is defined by a combination of a name and location.
  , _operationParameters :: [Referenced Parameter]

    -- | The list of possible responses as they are returned from executing this operation.
  , _operationResponses :: Responses

    -- | The transfer protocol for the operation.
    -- The value overrides @'schemes'@.
  , _operationSchemes :: Maybe [Scheme]

    -- | Declares this operation to be deprecated.
    -- Usage of the declared operation should be refrained.
    -- Default value is @False@.
  , _operationDeprecated :: Maybe Bool

    -- | A declaration of which security schemes are applied for this operation.
    -- The list of values describes alternative security schemes that can be used
    -- (that is, there is a logical OR between the security requirements).
    -- This definition overrides any declared top-level security.
    -- To remove a top-level security declaration, @Just []@ can be used.
  , _operationSecurity :: [SecurityRequirement]
  } deriving (Eq, Show, Generic)

newtype MimeList = MimeList { getMimeList :: [MediaType] }
  deriving (Eq, Show, Monoid)

-- | Describes a single operation parameter.
-- A unique parameter is defined by a combination of a name and location.
data Parameter = Parameter
  { -- | The name of the parameter.
    -- Parameter names are case sensitive.
    _parameterName :: Text

    -- | A brief description of the parameter.
    -- This could contain examples of use.
    -- GFM syntax can be used for rich text representation.
  , _parameterDescription :: Maybe Text

    -- | Determines whether this parameter is mandatory.
    -- If the parameter is in "path", this property is required and its value MUST be true.
    -- Otherwise, the property MAY be included and its default value is @False@.
  , _parameterRequired :: Maybe Bool

    -- | Parameter schema.
  , _parameterSchema :: ParameterSchema
  } deriving (Eq, Show, Generic)

data ParameterSchema
  = ParameterBody (Referenced SomeSchema)
  | ParameterOther ParameterOtherSchema
  deriving (Eq, Show)

data ParameterOtherSchema = ParameterOtherSchema
  { -- | The location of the parameter.
    _parameterOtherSchemaIn :: ParameterLocation

    -- | The type of the parameter.
    -- Since the parameter is not located at the request body,
    -- it is limited to simple types (that is, not an object).
    -- If type is @'ParamFile'@, the @consumes@ MUST be either
    -- "multipart/form-data" or " application/x-www-form-urlencoded"
    -- and the parameter MUST be in @'ParameterFormData'@.
  , _parameterOtherSchemaType :: ParameterType

    -- | The extending format for the previously mentioned type.
  , _parameterOtherSchemaFormat :: Maybe Format

    -- | Sets the ability to pass empty-valued parameters.
    -- This is valid only for either @'ParameterQuery'@ or @'ParameterFormData'@
    -- and allows you to send a parameter with a name only or an empty value.
    -- Default value is @False@.
  , _parameterOtherSchemaAllowEmptyValue :: Maybe Bool

    -- | __Required if type is @'ParamArray'@__.
    -- Describes the type of items in the array.
  , _parameterOtherSchemaItems :: Maybe Items

    -- | Determines the format of the array if @'ParamArray'@ is used.
    -- Default value is csv.
  , _parameterOtherSchemaCollectionFormat :: Maybe CollectionFormat

  , _parameterOtherSchemaCommon :: SchemaCommon
  } deriving (Eq, Show, Generic)

data ParameterType
  = ParamString
  | ParamNumber
  | ParamInteger
  | ParamBoolean
  | ParamArray
  | ParamFile
  deriving (Eq, Show)

data ParameterLocation
  = -- | Parameters that are appended to the URL.
    -- For example, in @/items?id=###@, the query parameter is @id@.
    ParameterQuery
    -- | Custom headers that are expected as part of the request.
  | ParameterHeader
    -- | Used together with Path Templating, where the parameter value is actually part of the operation's URL.
    -- This does not include the host or base path of the API.
    -- For example, in @/items/{itemId}@, the path parameter is @itemId@.
  | ParameterPath
    -- | Used to describe the payload of an HTTP request when either @application/x-www-form-urlencoded@
    -- or @multipart/form-data@ are used as the content type of the request
    -- (in Swagger's definition, the @consumes@ property of an operation).
    -- This is the only parameter type that can be used to send files, thus supporting the @'ParamFile'@ type.
    -- Since form parameters are sent in the payload, they cannot be declared together with a body parameter for the same operation.
    -- Form parameters have a different format based on the content-type used
    -- (for further details, consult <http://www.w3.org/TR/html401/interact/forms.html#h-17.13.4>).
  | ParameterFormData
  deriving (Eq, Show)

type Format = Text

-- | Determines the format of the array.
data CollectionFormat
  = CollectionCSV   -- ^ Comma separated values: @foo,bar@.
  | CollectionSSV   -- ^ Space separated values: @foo bar@.
  | CollectionTSV   -- ^ Tab separated values: @foo\\tbar@.
  | CollectionPipes -- ^ Pipe separated values: @foo|bar@.
  | CollectionMulti -- ^ Corresponds to multiple parameter instances
                           -- instead of multiple values for a single instance @foo=bar&foo=baz@.
                           -- This is valid only for parameters in @'ParameterQuery'@ or @'ParameterFormData'@.
  deriving (Eq, Show)

data ItemsType
  = ItemsString
  | ItemsNumber
  | ItemsInteger
  | ItemsBoolean
  | ItemsArray
  deriving (Eq, Show)

data SchemaType
  = SchemaArray
  | SchemaBoolean
  | SchemaInteger
  | SchemaNumber
  | SchemaNull
  | SchemaObject
  | SchemaString
  deriving (Eq, Show)

-- | Determines the format of the nested array.
data ItemsCollectionFormat
  = ItemsCollectionCSV   -- ^ Comma separated values: @foo,bar@.
  | ItemsCollectionSSV   -- ^ Space separated values: @foo bar@.
  | ItemsCollectionTSV   -- ^ Tab separated values: @foo\\tbar@.
  | ItemsCollectionPipes -- ^ Pipe separated values: @foo|bar@.
  deriving (Eq, Show)

type ParamName = Text

data SomeSchema = forall ty. KnownSchemaType ty => SomeSchema (Schema ty)

deriving instance Show SomeSchema

instance Eq SomeSchema where
  SomeSchema x == SomeSchema y =
    case testEquality (sSchemaType x) (sSchemaType y) of
      Nothing -> False
      Just Refl -> x == y

data SSchemaType ty where
  SSchemaArray :: SSchemaType 'SchemaArray
  SSchemaBoolean :: SSchemaType 'SchemaBoolean
  SSchemaInteger :: SSchemaType 'SchemaInteger
  SSchemaNumber :: SSchemaType 'SchemaNumber
  SSchemaNull :: SSchemaType 'SchemaNull
  SSchemaObject :: SSchemaType 'SchemaObject
  SSchemaString :: SSchemaType 'SchemaString

instance TestEquality SSchemaType where
  testEquality SSchemaArray SSchemaArray = Just Refl
  testEquality SSchemaBoolean SSchemaBoolean = Just Refl
  testEquality SSchemaInteger SSchemaInteger = Just Refl
  testEquality SSchemaNumber SSchemaNumber = Just Refl
  testEquality SSchemaNull SSchemaNull = Just Refl
  testEquality SSchemaObject SSchemaObject = Just Refl
  testEquality SSchemaString SSchemaString = Just Refl
  testEquality _ _ = Nothing

class KnownSchemaType ty where
  schemaType :: proxy ty -> SchemaType
  sSchemaType :: proxy ty -> SSchemaType ty

instance KnownSchemaType SchemaArray where schemaType _ = SchemaArray; sSchemaType _ = SSchemaArray
instance KnownSchemaType SchemaBoolean where schemaType _ = SchemaBoolean; sSchemaType _ = SSchemaBoolean
instance KnownSchemaType SchemaInteger where schemaType _ = SchemaInteger; sSchemaType _ = SSchemaInteger
instance KnownSchemaType SchemaNumber where schemaType _ = SchemaNumber; sSchemaType _ = SSchemaNumber
instance KnownSchemaType SchemaNull where schemaType _ = SchemaNull; sSchemaType _ = SSchemaNull
instance KnownSchemaType SchemaObject where schemaType _ = SchemaObject; sSchemaType _ = SSchemaObject
instance KnownSchemaType SchemaString where schemaType _ = SchemaString; sSchemaType _ = SSchemaString

data Schema ty = Schema
  { _schemaFormat :: Maybe Format
  , _schemaTitle :: Maybe Text
  , _schemaDescription :: Maybe Text
  , _schemaRequired :: [ParamName] `When` (ty == SchemaObject)

  , _schemaItems :: Maybe SchemaItems
  , _schemaAllOf :: Maybe [Schema ty]
  , _schemaProperties :: HashMap Text (Referenced SomeSchema)
  , _schemaAdditionalProperties :: Maybe SomeSchema

  , _schemaDiscriminator :: Maybe Text
  , _schemaReadOnly :: Maybe Bool
  , _schemaXml :: Maybe Xml
  , _schemaExternalDocs :: Maybe ExternalDocs
  , _schemaExample :: Maybe Value

  , _schemaMaxProperties :: Maybe Integer
  , _schemaMinProperties :: Maybe Integer

  , _schemaSchemaCommon :: SchemaCommon
  } deriving (Eq, Show, Generic)

data SchemaItems
  = SchemaItemsObject (Referenced SomeSchema)
  | SchemaItemsArray [Referenced SomeSchema]
  deriving (Eq, Show)

data SchemaCommon = SchemaCommon
  { -- | Declares the value of the parameter that the server will use if none is provided,
    -- for example a @"count"@ to control the number of results per page might default to @100@
    -- if not supplied by the client in the request.
    -- (Note: "default" has no meaning for required parameters.)
    -- Unlike JSON Schema this value MUST conform to the defined type for this parameter.
    _schemaCommonDefault :: Maybe Value

  , _schemaCommonMaximum :: Maybe Integer
  , _schemaCommonExclusiveMaximum :: Maybe Bool
  , _schemaCommonMinimum :: Maybe Integer
  , _schemaCommonExclusiveMinimum :: Maybe Bool
  , _schemaCommonMaxLength :: Maybe Integer
  , _schemaCommonMinLength :: Maybe Integer
  , _schemaCommonPattern :: Maybe Text
  , _schemaCommonMaxItems :: Maybe Integer
  , _schemaCommonMinItems :: Maybe Integer
  , _schemaCommonUniqueItems :: Maybe Bool
  , _schemaCommonEnum :: Maybe [Value]
  , _schemaCommonMultipleOf :: Maybe Integer
  } deriving (Eq, Show, Generic)

data Xml = Xml
  { -- | Replaces the name of the element/attribute used for the described schema property.
    -- When defined within the @'Items'@ (items), it will affect the name of the individual XML elements within the list.
    -- When defined alongside type being array (outside the items),
    -- it will affect the wrapping element and only if wrapped is true.
    -- If wrapped is false, it will be ignored.
    _xmlName :: Maybe Text

    -- | The URL of the namespace definition.
    -- Value SHOULD be in the form of a URL.
  , _xmlNamespace :: Maybe Text

    -- | The prefix to be used for the name.
  , _xmlPrefix :: Maybe Text

    -- | Declares whether the property definition translates to an attribute instead of an element.
    -- Default value is @False@.
  , _xmlAttribute :: Maybe Bool

    -- | MAY be used only for an array definition.
    -- Signifies whether the array is wrapped
    -- (for example, @\<books\>\<book/\>\<book/\>\</books\>@)
    -- or unwrapped (@\<book/\>\<book/\>@).
    -- Default value is @False@.
    -- The definition takes effect only when defined alongside type being array (outside the items).
  , _xmlWrapped :: Maybe Bool
  } deriving (Eq, Show, Generic)

data Items = Items
  { -- | The internal type of the array.
    _itemsType :: ItemsType

    -- | The extending format for the previously mentioned type.
  , _itemsFormat :: Maybe Format

    -- | __Required if type is @'ItemsArray'@.__
    -- Describes the type of items in the array.
  , _itemsItems :: Maybe Items

    -- | Determines the format of the array if type array is used.
    -- Default value is @'ItemsCollectionCSV'@.
  , _itemsCollectionFormat :: Maybe ItemsCollectionFormat

  , _itemsCommon :: SchemaCommon
  } deriving (Eq, Show, Generic)

-- | A container for the expected responses of an operation.
-- The container maps a HTTP response code to the expected response.
-- It is not expected from the documentation to necessarily cover all possible HTTP response codes,
-- since they may not be known in advance.
-- However, it is expected from the documentation to cover a successful operation response and any known errors.
data Responses = Responses
  { -- | The documentation of responses other than the ones declared for specific HTTP response codes.
    -- It can be used to cover undeclared responses.
   _responsesDefault :: Maybe (Referenced Response)

    -- | Any HTTP status code can be used as the property name (one property per HTTP status code).
    -- Describes the expected response for those HTTP status codes.
  , _responsesResponses :: HashMap HttpStatusCode (Referenced Response)
  } deriving (Eq, Show, Generic)

type HttpStatusCode = Int

-- | Describes a single response from an API Operation.
data Response = Response
  { -- | A short description of the response.
    -- GFM syntax can be used for rich text representation.
    _responseDescription :: Text

    -- | A definition of the response structure.
    -- It can be a primitive, an array or an object.
    -- If this field does not exist, it means no content is returned as part of the response.
    -- As an extension to the Schema Object, its root type value may also be "file".
    -- This SHOULD be accompanied by a relevant produces mime-type.
  , _responseSchema :: Maybe (Referenced SomeSchema)

    -- | A list of headers that are sent with the response.
  , _responseHeaders :: HashMap HeaderName Header

    -- | An example of the response message.
  , _responseExamples :: Maybe Example
  } deriving (Eq, Show, Generic)

type HeaderName = Text

data Header = Header
  { -- | A short description of the header.
    _headerDescription :: Maybe Text

    -- | The type of the object.
  , _headerType :: ItemsType

    -- | The extending format for the previously mentioned type. See Data Type Formats for further details.
  , _headerFormat :: Maybe Format

    -- | __Required if type is @'ItemsArray'@__.
    -- Describes the type of items in the array.
  , _headerItems :: Maybe Items

    -- | Determines the format of the array if type array is used.
    -- Default value is @'ItemsCollectionCSV'@.
  , _headerCollectionFormat :: Maybe ItemsCollectionFormat

  , _headerCommon :: SchemaCommon
  } deriving (Eq, Show, Generic)

data Example = Example { getExample :: Map MediaType Value }
  deriving (Eq, Show)

-- | The location of the API key.
data ApiKeyLocation
  = ApiKeyQuery
  | ApiKeyHeader
  deriving (Eq, Show)

data ApiKeyParams = ApiKeyParams
  { -- | The name of the header or query parameter to be used.
    _apiKeyName :: Text

    -- | The location of the API key.
  , _apiKeyIn :: ApiKeyLocation
  } deriving (Eq, Show)

-- | The authorization URL to be used for OAuth2 flow. This SHOULD be in the form of a URL.
type AuthorizationURL = Text

-- | The token URL to be used for OAuth2 flow. This SHOULD be in the form of a URL.
type TokenURL = Text

data OAuth2Flow
  = OAuth2Implicit AuthorizationURL
  | OAuth2Password TokenURL
  | OAuth2Application TokenURL
  | OAuth2AccessCode AuthorizationURL TokenURL
  deriving (Eq, Show)

data OAuth2Params = OAuth2Params
  { -- | The flow used by the OAuth2 security scheme.
    _oauth2Flow :: OAuth2Flow

    -- | The available scopes for the OAuth2 security scheme.
  , _oauth2Scopes :: HashMap Text Text
  } deriving (Eq, Show, Generic)

data SecuritySchemeType
  = SecuritySchemeBasic
  | SecuritySchemeApiKey ApiKeyParams
  | SecuritySchemeOAuth2 OAuth2Params
  deriving (Eq, Show)

data SecurityScheme = SecurityScheme
  { -- | The type of the security scheme.
    _securitySchemeType :: SecuritySchemeType

    -- | A short description for security scheme.
  , _securitySchemeDescription :: Maybe Text
  } deriving (Eq, Show, Generic)

-- | Lists the required security schemes to execute this operation.
-- The object can have multiple security schemes declared in it which are all required
-- (that is, there is a logical AND between the schemes).
newtype SecurityRequirement = SecurityRequirement
  { getSecurityRequirement :: HashMap Text [Text]
  } deriving (Eq, Read, Show, Monoid, ToJSON, FromJSON)

-- | Allows adding meta data to a single tag that is used by @Operation@.
-- It is not mandatory to have a @Tag@ per tag used there.
data Tag = Tag
  { -- | The name of the tag.
    _tagName :: Text

    -- | A short description for the tag.
    -- GFM syntax can be used for rich text representation.
  , _tagDescription :: Maybe Text

    -- | Additional external documentation for this tag.
  , _tagExternalDocs :: Maybe ExternalDocs
  } deriving (Eq, Show)

-- | Allows referencing an external resource for extended documentation.
data ExternalDocs = ExternalDocs
  { -- | A short description of the target documentation.
    -- GFM syntax can be used for rich text representation.
    _externalDocsDescription :: Maybe Text

    -- | The URL for the target documentation.
  , _externalDocsUrl :: URL
  } deriving (Eq, Show, Generic)

-- | A simple object to allow referencing other definitions in the specification.
-- It can be used to reference parameters and responses that are defined at the top level for reuse.
newtype Reference = Reference { getReference :: Text }
  deriving (Eq, Show)

data Referenced a
  = Ref Reference
  | Inline a
  deriving (Eq, Show)

newtype URL = URL { getUrl :: Text } deriving (Eq, Show, ToJSON, FromJSON)

-- =======================================================================
-- Monoid instances
-- =======================================================================

instance Monoid Swagger where
  mempty = genericMempty
  mappend = genericMappend

instance Monoid Info where
  mempty = genericMempty
  mappend = genericMappend

instance Monoid Paths where
  mempty = genericMempty
  mappend = genericMappend

instance Monoid PathItem where
  mempty = genericMempty
  mappend = genericMappend

instance (SwaggerMonoid ([ParamName] `When` (ty == 'SchemaObject))) => Monoid (Schema ty) where
  mempty = genericMempty
  mappend = genericMappend

instance Monoid SchemaCommon where
  mempty = genericMempty
  mappend = genericMappend

instance Monoid Parameter where
  mempty = genericMempty
  mappend = genericMappend

instance Monoid ParameterOtherSchema where
  mempty = genericMempty
  mappend = genericMappend

instance Monoid Responses where
  mempty = genericMempty
  mappend = genericMappend

instance Monoid Response where
  mempty = genericMempty
  mappend = genericMappend

instance Monoid ExternalDocs where
  mempty = genericMempty
  mappend = genericMappend

instance Monoid Operation where
  mempty = genericMempty
  mappend = genericMappend

-- =======================================================================
-- SwaggerMonoid helper instances
-- =======================================================================

instance SwaggerMonoid Info
instance SwaggerMonoid Paths
instance SwaggerMonoid PathItem

instance SwaggerMonoid (Schema 'SchemaObject)

instance SwaggerMonoid SchemaCommon
instance SwaggerMonoid Parameter
instance SwaggerMonoid ParameterOtherSchema
instance SwaggerMonoid Responses
instance SwaggerMonoid Response
instance SwaggerMonoid ExternalDocs
instance SwaggerMonoid Operation

instance SwaggerMonoid MimeList
deriving instance SwaggerMonoid URL

instance SwaggerMonoid SchemaType where
  swaggerMempty = SchemaNull
  swaggerMappend _ y = y

instance SwaggerMonoid ParameterType where
  swaggerMempty = ParamString
  swaggerMappend _ y = y

instance SwaggerMonoid ParameterLocation where
  swaggerMempty = ParameterQuery
  swaggerMappend _ y = y

instance SwaggerMonoid (HashMap Text SomeSchema) where
  swaggerMempty = HashMap.empty
  swaggerMappend = HashMap.unionWith mappend

instance SwaggerMonoid (HashMap Text (Referenced SomeSchema)) where
  swaggerMempty = HashMap.empty
  swaggerMappend = HashMap.unionWith swaggerMappend

instance Monoid a => SwaggerMonoid (Referenced a) where
  swaggerMempty = Inline mempty
  swaggerMappend (Inline x) (Inline y) = Inline (x <> y)
  swaggerMappend _ y = y

instance SwaggerMonoid (HashMap Text Parameter) where
  swaggerMempty = HashMap.empty
  swaggerMappend = HashMap.unionWith mappend

instance SwaggerMonoid (HashMap Text Response) where
  swaggerMempty = HashMap.empty
  swaggerMappend = flip HashMap.union

instance SwaggerMonoid (HashMap Text SecurityScheme) where
  swaggerMempty = HashMap.empty
  swaggerMappend = flip HashMap.union

instance SwaggerMonoid (HashMap FilePath PathItem) where
  swaggerMempty = HashMap.empty
  swaggerMappend = HashMap.unionWith mappend

instance SwaggerMonoid (HashMap HeaderName Header) where
  swaggerMempty = HashMap.empty
  swaggerMappend = flip HashMap.union

instance SwaggerMonoid (HashMap HttpStatusCode (Referenced Response)) where
  swaggerMempty = HashMap.empty
  swaggerMappend = flip HashMap.union

instance SwaggerMonoid ParameterSchema where
  swaggerMempty = ParameterOther swaggerMempty
  swaggerMappend (ParameterBody x) (ParameterBody y) = ParameterBody (swaggerMappend x y)
  swaggerMappend (ParameterOther x) (ParameterOther y) = ParameterOther (swaggerMappend x y)
  swaggerMappend _ y = y

-- =======================================================================
-- TH derived ToJSON and FromJSON instances
-- =======================================================================

deriveJSON (jsonPrefix "Parameter") ''ParameterLocation
deriveJSON (jsonPrefix "Param") ''ParameterType
deriveJSON' ''Info
deriveJSON' ''Contact
deriveJSON' ''License
deriveJSON (jsonPrefix "Schema") ''SchemaType
deriveJSON (jsonPrefix "Items") ''ItemsType
deriveJSON (jsonPrefix "ItemsCollection") ''ItemsCollectionFormat
deriveJSON (jsonPrefix "Collection") ''CollectionFormat
deriveJSON (jsonPrefix "ApiKey") ''ApiKeyLocation
deriveJSON (jsonPrefix "apiKey") ''ApiKeyParams
deriveJSON' ''SchemaCommon
deriveJSONDefault ''Scheme
deriveJSON' ''Tag
deriveJSON' ''ExternalDocs

deriveToJSON' ''Operation
deriveToJSON' ''Response
deriveToJSON' ''PathItem
deriveToJSON' ''Xml

-- =======================================================================
-- Manual ToJSON instances
-- =======================================================================

instance ToJSON OAuth2Flow where
  toJSON (OAuth2Implicit authUrl) = object
    [ "flow"             .= ("implicit" :: Text)
    , "authorizationUrl" .= authUrl ]
  toJSON (OAuth2Password tokenUrl) = object
    [ "flow"     .= ("password" :: Text)
    , "tokenUrl" .= tokenUrl ]
  toJSON (OAuth2Application tokenUrl) = object
    [ "flow"     .= ("application" :: Text)
    , "tokenUrl" .= tokenUrl ]
  toJSON (OAuth2AccessCode authUrl tokenUrl) = object
    [ "flow"             .= ("accessCode" :: Text)
    , "authorizationUrl" .= authUrl
    , "tokenUrl"         .= tokenUrl ]

instance ToJSON OAuth2Params where
  toJSON = genericToJSONWithSub "flow" (jsonPrefix "oauth2")

instance ToJSON SecuritySchemeType where
  toJSON SecuritySchemeBasic
      = object [ "type" .= ("basic" :: Text) ]
  toJSON (SecuritySchemeApiKey params)
      = toJSON params
    <+> object [ "type" .= ("apiKey" :: Text) ]
  toJSON (SecuritySchemeOAuth2 params)
      = toJSON params
    <+> object [ "type" .= ("oauth2" :: Text) ]

instance ToJSON Swagger where
  toJSON = addVersion . genericToJSON (jsonPrefix "")
    where
      addVersion (Object o) = Object (HashMap.insert "swagger" "2.0" o)
      addVersion _ = error "impossible"

instance ToJSON SecurityScheme where
  toJSON = genericToJSONWithSub "type" (jsonPrefix "securityScheme")

instance ToJSON (Schema ty) where
  toJSON = genericToJSONWithSub "schemaCommon" (jsonPrefix "schema")

instance ToJSON Header where
  toJSON = genericToJSONWithSub "common" (jsonPrefix "header")

instance ToJSON Items where
  toJSON = genericToJSONWithSub "common" (jsonPrefix "items")

instance ToJSON Host where
  toJSON (Host host mport) = toJSON $
    case mport of
      Nothing -> host
      Just port -> host ++ ":" ++ show port

instance ToJSON Paths where
  toJSON (Paths m) = toJSON m

instance ToJSON MimeList where
  toJSON (MimeList xs) = toJSON (map show xs)

instance ToJSON Parameter where
  toJSON = genericToJSONWithSub "schema" (jsonPrefix "parameter")

instance ToJSON ParameterSchema where
  toJSON (ParameterBody s) = object [ "in" .= ("body" :: Text), "schema" .= s ]
  toJSON (ParameterOther s) = toJSON s

instance ToJSON ParameterOtherSchema where
  toJSON = genericToJSONWithSub "common" (jsonPrefix "parameterOtherSchema")

instance ToJSON SchemaItems where
  toJSON (SchemaItemsObject x) = toJSON x
  toJSON (SchemaItemsArray xs) = toJSON xs

instance ToJSON Responses where
  toJSON (Responses def rs) = toJSON (hashMapMapKeys show rs) <+> object [ "default" .= def ]

instance ToJSON Example where
  toJSON = toJSON . Map.mapKeys show . getExample

instance ToJSON Reference where
  toJSON (Reference ref) = object [ "$ref" .= ref ]

instance ToJSON a => ToJSON (Referenced a) where
  toJSON (Ref ref) = toJSON ref
  toJSON (Inline x) = toJSON x

-- =======================================================================
-- Manual FromJSON instances
-- =======================================================================

instance FromJSON OAuth2Flow where
  parseJSON (Object o) = do
    (flow :: Text) <- o .: "flow"
    case flow of
      "implicit"    -> OAuth2Implicit    <$> o .: "authorizationUrl"
      "password"    -> OAuth2Password    <$> o .: "tokenUrl"
      "application" -> OAuth2Application <$> o .: "tokenUrl"
      "accessCode"  -> OAuth2AccessCode
        <$> o .: "authorizationUrl"
        <*> o .: "tokenUrl"
      _ -> empty
  parseJSON _ = empty

instance FromJSON OAuth2Params where
  parseJSON = genericParseJSONWithSub "flow" (jsonPrefix "oauth2")

instance FromJSON SecuritySchemeType where
  parseJSON json@(Object o) = do
    (t :: Text) <- o .: "type"
    case t of
      "basic"  -> pure SecuritySchemeBasic
      "apiKey" -> SecuritySchemeApiKey <$> parseJSON json
      "oauth2" -> SecuritySchemeOAuth2 <$> parseJSON json
      _ -> empty
  parseJSON _ = empty

instance FromJSON Swagger where
  parseJSON json@(Object o) = do
    (version :: Text) <- o .: "swagger"
    when (version /= "2.0") empty
    (genericParseJSON (jsonPrefix "")
      `withDefaults` [ "consumes" .= (mempty :: MimeList)
                     , "produces" .= (mempty :: MimeList)
                     , "security" .= ([] :: [SecurityRequirement])
                     , "tags" .= ([] :: [Tag])
                     , "definitions" .= (mempty :: HashMap Text SomeSchema)
                     , "parameters" .= (mempty :: HashMap Text Parameter)
                     , "responses" .= (mempty :: HashMap Text Response)
                     , "securityDefinitions" .= (mempty :: HashMap Text SecurityScheme)
                     ] ) json
  parseJSON _ = empty

instance FromJSON SecurityScheme where
  parseJSON = genericParseJSONWithSub "type" (jsonPrefix "securityScheme")

instance FromJSON SomeSchema where
  parseJSON = genericParseJSONWithSub "schemaCommon" (jsonPrefix "schema")
    `withDefaults` [ "properties" .= (mempty :: HashMap Text SomeSchema)
                   , "required"   .= ([] :: [ParamName]) ]

instance FromJSON Header where
  parseJSON = genericParseJSONWithSub "common" (jsonPrefix "header")

instance FromJSON Items where
  parseJSON = genericParseJSONWithSub "common" (jsonPrefix "items")

instance FromJSON Host where
  parseJSON (String s) =
    case fromInteger <$> readMaybe portStr of
      Nothing | not (null portStr) -> fail $ "Invalid port `" ++ portStr ++ "'"
      mport -> pure $ Host host mport
    where
      (hostText, portText) = Text.breakOn ":" s
      [host, portStr] = map Text.unpack [hostText, portText]
  parseJSON _ = empty

instance FromJSON Paths where
  parseJSON json = Paths <$> parseJSON json

instance FromJSON MimeList where
  parseJSON json = (MimeList . map fromString) <$> parseJSON json

instance FromJSON Parameter where
  parseJSON = genericParseJSONWithSub "schema" (jsonPrefix "parameter")

instance FromJSON ParameterSchema where
  parseJSON json@(Object o) = do
    (i :: Text) <- o .: "in"
    case i of
      "body" -> do
        schema <- o .: "schema"
        ParameterBody <$> parseJSON schema
      _ -> ParameterOther <$> parseJSON json
  parseJSON _ = empty

instance FromJSON ParameterOtherSchema where
  parseJSON = genericParseJSONWithSub "common" (jsonPrefix "parameterOtherSchema")

instance FromJSON SchemaItems where
  parseJSON json@(Object _) = SchemaItemsObject <$> parseJSON json
  parseJSON json@(Array _) = SchemaItemsArray <$> parseJSON json
  parseJSON _ = empty

instance FromJSON Responses where
  parseJSON (Object o) = Responses
    <$> o .:? "default"
    <*> (parseJSON (Object (HashMap.delete "default" o)) >>= hashMapReadKeys)
  parseJSON _ = empty

instance FromJSON Example where
  parseJSON json = do
    m <- parseJSON json
    pure $ Example (Map.mapKeys fromString m)

instance FromJSON Response where
  parseJSON = genericParseJSON (jsonPrefix "response")
    `withDefaults` [ "headers" .= (mempty :: HashMap HeaderName Header) ]

instance FromJSON Operation where
  parseJSON = genericParseJSON (jsonPrefix "operation")
    `withDefaults` [ "security"   .= ([] :: [SecurityRequirement]) ]

instance FromJSON PathItem where
  parseJSON = genericParseJSON (jsonPrefix "pathItem")
    `withDefaults` [ "parameters" .= ([] :: [Parameter]) ]

instance FromJSON Reference where
  parseJSON (Object o) = Reference <$> o .: "$ref"
  parseJSON _ = empty

instance FromJSON a => FromJSON (Referenced a) where
  parseJSON json
      = Ref    <$> parseJSON json
    <|> Inline <$> parseJSON json

instance FromJSON Xml where
  parseJSON = genericParseJSON (jsonPrefix "xml")

