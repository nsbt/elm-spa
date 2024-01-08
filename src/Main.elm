module Main exposing (main)

import Browser
import Browser.Navigation as Nav
import Url
import Url.Builder
import Http
import Html exposing (..)
import Html.Attributes exposing (..)
import Json.Decode as D

import Route exposing (Route)

main : Program () Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = UrlRequested
        }


-- MODEL

type alias Model =
    { key : Nav.Key
    , page : Page
    }
    
type Page
    = NotFound
    | ErrorPage Http.Error
    | TopPage
    | UserPage (List Repo)
    | RepoPage (List Issue)

type alias Repo =
    { name : String
    }

type alias Issue =
    { number : Int
    , title : String
    , state : String
    }

init : () -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    Model key TopPage
        |> goTo (Route.fromUrl url)

-- UPDATE

type Msg
    = UrlRequested Browser.UrlRequest
    | UrlChanged Url.Url
    | Loaded (Result Http.Error Page)

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UrlRequested urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    (model, Nav.pushUrl model.key (Url.toString url))
                Browser.External href ->
                    (model, Nav.load href)
        UrlChanged url ->
            goTo (Route.fromUrl url) model
        Loaded result ->
            ({ model
                | page =
                    case result of
                        Ok page ->
                            page
                        Err e ->
                            ErrorPage e
            }
            , Cmd.none
            )

goTo : Maybe Route -> Model -> (Model, Cmd Msg)
goTo maybeRoute model =
    case maybeRoute of
        Nothing ->
            ({ model | page = NotFound }, Cmd.none)
        Just Route.Top ->
            ({ model | page = TopPage }, Cmd.none)
        Just (Route.User userName) ->
            ({ model | page = UserPage [ (Repo "repo1") ]}, Cmd.none)
        Just (Route.Repo userName repoName) ->
            ( model
            , Http.get
                { url =
                    Url.Builder.crossOrigin "https://api.github.com"
                        [ "repos", userName, repoName, "issues" ]
                        []
                , expect =
                    Http.expectJson
                        (Result.map RepoPage >> Loaded)
                        issuesDecoder
                }
            )

issuesDecoder : D.Decoder (List Issue)
issuesDecoder =
    D.list
        (D.map3 Issue
            (D.field "number" D.int)
            (D.field "title" D.string)
            (D.field "state" D.string)
        )
        

-- SUBSCRIPTIONS

subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


-- VIEW

view : Model -> Browser.Document Msg
view model =
    { title = "GitHub viewer"
    , body =
        [ a [ href "/" ] [ h1 [] [ text "GitHub viewer" ] ]
        , case model.page of
            NotFound ->
                text "not found"
            ErrorPage error ->
                text "something is wrong"
            TopPage ->
                ulUsers
            UserPage repos ->
                text "user page"
            RepoPage issues ->
                ulIssues issues
        ]
    }

ulUsers : Html Msg
ulUsers =
    ul []
        [ liUser (Url.Builder.absolute [ "nsbt" ] [])
        , liUser (Url.Builder.absolute [ "evancz" ] [])
        , liUser (Url.Builder.absolute [ "elm" ] [])
        ]

liUser : String -> Html Msg
liUser userName =
    li [] [ a [ href userName ] [ text userName ]]

ulIssues : List Issue -> Html Msg
ulIssues issues =
    ul [] (List.map liIssue issues)

liIssue : Issue -> Html msg
liIssue issue =
    li []
        [ span [] [ text ("[" ++ issue.state ++ "]") ]
        , span [] [ text ("#" ++ String.fromInt issue.number) ]
        , span [] [ text issue.title ]
        ]
