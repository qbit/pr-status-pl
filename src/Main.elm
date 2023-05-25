module Main exposing (..)

import Browser
import Css exposing (padding, px)
import Html.Styled exposing (..)
import Html.Styled.Attributes exposing (css, disabled, href, placeholder, style)
import Html.Styled.Events exposing (onClick, onInput)
import Http
import Json.Decode as Decode exposing (Decoder, field, int, list, map5, string)


type Status
    = Complete
    | Open


type Msg
    = RunSearch
    | GotResult (Result Http.Error Model)
    | SetPR String


type alias Branches =
    List String


type alias Model =
    { pull_request : Int
    , release : String
    , status : Status
    , title : String
    , branches : Branches
    , error : String
    }


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , view = view >> toUnstyled
        , update = update
        , subscriptions = \_ -> Sub.none
        }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        RunSearch ->
            ( model, getResult model )

        GotResult (Err _) ->
            ( { model | error = "Can't load data!" }, Cmd.none )

        GotResult (Ok pr) ->
            ( pr, Cmd.none )

        SetPR pr ->
            ( { model
                | pull_request =
                    case String.toInt pr of
                        Just a ->
                            a

                        Nothing ->
                            0
              }
            , Cmd.none
            )


initialModel : Model
initialModel =
    { pull_request = 0
    , release = ""
    , status = Open
    , title = ""
    , branches = []
    , error = ""
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( initialModel, Cmd.none )


view : Model -> Html Msg
view model =
    div
        [ css
            [ padding (px 30)
            ]
        ]
        [ div []
            [ div []
                [ input [ placeholder "search...", onInput SetPR ] []
                , button
                    [ onClick RunSearch
                    , disabled (viewValidation model)
                    ]
                    [ text "Search" ]
                ]
            , div []
                [ viewResult model
                ]
            ]
        ]


viewValidation : Model -> Bool
viewValidation model =
    case model.pull_request of
        0 ->
            True

        _ ->
            False


viewResult : Model -> Html Msg
viewResult data =
    case data.title of
        "" ->
            text ""

        _ ->
            let
                prStr =
                    String.fromInt data.pull_request
            in
            table
                []
                [ tr []
                    [ td [] [ b [] [ text "Title:" ] ]
                    , td []
                        [ a [ href ("https://github.com/NixOS/nixpkgs/pull/" ++ prStr) ]
                            [ text data.title
                            ]
                        ]
                    ]
                , makeRow "Release:" data.release
                , makeRow "Status:"
                    (case data.status of
                        Complete ->
                            "complete"

                        Open ->
                            "open"
                    )
                , viewBranches data.branches
                , case data.error of
                    "" ->
                        text ""

                    _ ->
                        span [ style "color" "red" ] [ text data.error ]
                ]


viewBranches : List String -> Html Msg
viewBranches blist =
    tr []
        [ td [] [ b [] [ text "Branches:" ] ]
        , td []
            [ ul []
                (List.map viewBranch blist)
            ]
        ]


viewBranch : String -> Html Msg
viewBranch branch =
    li [] [ text branch ]


makeRow : String -> String -> Html Msg
makeRow title data =
    tr []
        [ td [] [ b [] [ text title ] ]
        , td [] [ text data ]
        ]


getResult : Model -> Cmd Msg
getResult model =
    Http.get
        { url = "/" ++ String.fromInt model.pull_request
        , expect = Http.expectJson GotResult resultDecoder
        }


resultDecoder : Decoder Model
resultDecoder =
    map5
        (\pull_request release status title branches ->
            { pull_request = pull_request
            , release = release
            , status = status
            , title = title
            , branches = branches
            , error = ""
            }
        )
        (field "pull_request" int)
        (field "release" string)
        (field "status" statusDecoder)
        (field "title" string)
        (field "branches" (list string))


statusDecoder : Decoder Status
statusDecoder =
    Decode.string
        |> Decode.andThen
            (\str ->
                case str of
                    "complete" ->
                        Decode.succeed Complete

                    "open" ->
                        Decode.succeed Open

                    _ ->
                        Decode.fail "invalid status"
            )
