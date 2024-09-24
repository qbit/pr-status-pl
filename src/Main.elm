module Main exposing (Branches, Model, Status, main, resultDecoder, statusDecoder)

import Browser exposing (Document)
import Css exposing (..)
import Css.Animations exposing (keyframes)
import Html.Styled exposing (..)
import Html.Styled.Attributes exposing (class, css, href, placeholder, style)
import Html.Styled.Events exposing (onClick, onInput)
import Http exposing (..)
import Json.Decode as Decode exposing (Decoder, field, list, map2, map7, string)


type Status
    = Complete
    | Open


type WorkAction
    = NoOp
    | GC
    | Update


type Msg
    = RunSearch
    | SearchPR Int
    | DeleteSearchPR Int
    | GotResult (Result Http.Error Model)
    | GCResult (Result Http.Error WorkStatus)
    | GotSearches (Result Http.Error Searches)
    | UpdateResult (Result Http.Error WorkStatus)
    | SetPR String
    | UpdateBackend
    | CollectGarbage


type alias Branches =
    List String


type alias WorkStatus =
    { action : WorkAction
    , updateTime : Float
    }


type alias Search =
    { pull_request : Int
    , title : String
    }


type alias Searches =
    List Search


type alias Model =
    { pull_request : Int
    , release : String
    , status : Status
    , title : String
    , searches : Searches
    , branches : Branches
    , error : String
    , loading : Bool
    , updateStatus : WorkStatus
    , gcStatus : WorkStatus
    }


main : Program () Model Msg
main =
    Browser.document
        { init = init
        , view = view
        , update = update
        , subscriptions = \_ -> Sub.none
        }


httpErr : Http.Error -> String
httpErr error =
    case error of
        BadUrl url ->
            "Bad url: " ++ url

        Timeout ->
            "Timed out.."

        NetworkError ->
            "Network error.. are you connected?"

        BadStatus status ->
            "Bad status: " ++ String.fromInt status

        BadBody body ->
            "Bad body: '" ++ body ++ "'"


loadingModel : Model
loadingModel =
    { initialModel | loading = True }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        RunSearch ->
            ( loadingModel, getResult model.pull_request )

        GotResult (Err err) ->
            ( { model | error = "Error: " ++ httpErr err, loading = False }, Cmd.none )

        GotResult (Ok pr) ->
            ( pr, Cmd.none )

        GotSearches (Err err) ->
            ( { model | error = "Error: " ++ httpErr err, loading = False }, Cmd.none )

        GotSearches (Ok searches) ->
            ( { model | searches = searches }, Cmd.none )

        GCResult (Err err) ->
            ( { model | error = "Error: " ++ httpErr err, loading = False }, Cmd.none )

        GCResult (Ok resp) ->
            ( { model | gcStatus = resp, loading = False }, Cmd.none )

        UpdateResult (Err err) ->
            ( { model | error = "Error: " ++ httpErr err, loading = False }, Cmd.none )

        UpdateResult (Ok resp) ->
            ( { model | updateStatus = resp, loading = False }, Cmd.none )

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

        SearchPR pr ->
            ( loadingModel, getResult pr )

        DeleteSearchPR pr ->
            ( model, deleteSearchPR pr )

        CollectGarbage ->
            ( loadingModel, getGC )

        UpdateBackend ->
            ( loadingModel, getUpdate )


initialModel : Model
initialModel =
    { pull_request = 0
    , release = ""
    , status = Open
    , title = ""
    , branches = []
    , searches = []
    , error = ""
    , loading = False
    , updateStatus =
        { action = NoOp
        , updateTime = 0.0
        }
    , gcStatus =
        { action = NoOp
        , updateTime = 0.0
        }
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( initialModel, getSearches )


loading : Html msg
loading =
    span
        [ css
            [ animationName (keyframes [ ( 5, [ Css.Animations.property "rotate" "360deg" ] ) ])
            , animationDuration (sec 0.75)
            , animationIterationCount infinite
            , boxSizing borderBox
            , borderRadius (pct 50)
            , border3 (px 2) solid (rgb 160 160 160)
            , borderTopColor (rgb 0 0 0)
            , width (px 20)
            , height (px 20)
            , marginLeft (px 10)
            , position absolute
            ]
        ]
        [ text "" ]


view : Model -> Document Msg
view model =
    { body =
        [ Html.Styled.toUnstyled
            (div
                [ css
                    [ padding (px 30)
                    ]
                ]
                [ div []
                    [ div []
                        [ input [ placeholder "search...", onInput SetPR ] []
                        , button
                            [ onClick RunSearch
                            , Html.Styled.Attributes.disabled (viewValidation model)
                            ]
                            [ text "Search" ]
                        , span
                            [ Html.Styled.Attributes.hidden (not model.loading)
                            ]
                            [ loading ]
                        ]
                    , div []
                        [ viewResult model
                        ]
                    ]
                , case model.error of
                    "" ->
                        text ""

                    _ ->
                        span [ style "color" "red" ] [ text model.error ]
                , hr [] []
                , div []
                    [ viewSearches model.searches
                    ]
                , hr [] []
                , div []
                    [ button
                        [ onClick UpdateBackend
                        , Html.Styled.Attributes.disabled model.loading
                        ]
                        [ text "Update Backend" ]
                    , button
                        [ onClick CollectGarbage
                        , Html.Styled.Attributes.disabled model.loading
                        ]
                        [ text "Collect Garbage" ]
                    , p []
                        [ i []
                            [ viewWorkAction model.gcStatus
                            , viewWorkAction model.updateStatus
                            ]
                        ]
                    ]
                ]
            )
        ]
    , title = "pr-status"
    }


viewSearch : Search -> Html Msg
viewSearch search =
    let
        prStr =
            String.fromInt search.pull_request
    in
    ol []
        [ span [ style "cursor" "pointer", onClick (SearchPR search.pull_request) ] [ text "⟳" ]
        , text " "
        , span [ style "cursor" "pointer", onClick (DeleteSearchPR search.pull_request) ] [ text "-" ]
        , text " "
        , text prStr
        , text (": " ++ search.title)
        , ul []
            [ li [] [ a [ href ("https://github.com/NixOS/nixpkgs/pull/" ++ prStr) ] [ text "nixpkgs" ] ]
            , li [] [ a [ href ("/" ++ prStr) ] [ text "json" ] ]
            ]
        ]


viewSearches : Searches -> Html Msg
viewSearches searches =
    ul []
        (List.map
            viewSearch
            searches
        )


viewWorkAction : WorkStatus -> Html Msg
viewWorkAction work =
    case work.action of
        NoOp ->
            text ""

        GC ->
            text ("Garbage collection took: " ++ String.fromFloat work.updateTime ++ " seconds.")

        Update ->
            text ("Update took: " ++ String.fromFloat work.updateTime ++ " seconds.")


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
            Html.Styled.table
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


deleteSearchPR : Int -> Cmd Msg
deleteSearchPR pr =
    Http.request
        { method = "DELETE"
        , headers = []
        , url = "/searches/" ++ String.fromInt pr
        , body = Http.emptyBody
        , expect = Http.expectJson GotSearches searchListDecoder
        , timeout = Nothing
        , tracker = Nothing
        }


getResult : Int -> Cmd Msg
getResult pr =
    Http.get
        { url = "/" ++ String.fromInt pr
        , expect = Http.expectJson GotResult resultDecoder
        }


getSearches : Cmd Msg
getSearches =
    Http.get
        { url = "/searches"
        , expect = Http.expectJson GotSearches searchListDecoder
        }


getGC : Cmd Msg
getGC =
    Http.get
        { url = "/gc"
        , expect = Http.expectJson GCResult workStatusDecoder
        }


getUpdate : Cmd Msg
getUpdate =
    Http.get
        { url = "/update"
        , expect = Http.expectJson UpdateResult workStatusDecoder
        }


actionDecoder : Decoder WorkAction
actionDecoder =
    Decode.string
        |> Decode.andThen
            (\str ->
                case str of
                    "gc" ->
                        Decode.succeed GC

                    "update" ->
                        Decode.succeed Update

                    "" ->
                        Decode.succeed NoOp

                    _ ->
                        Decode.fail "invalid action"
            )


workStatusDecoder : Decoder WorkStatus
workStatusDecoder =
    map2 WorkStatus
        (field "action" actionDecoder)
        (field "updateTime" Decode.float)


searchListDecoder : Decoder Searches
searchListDecoder =
    list searchDecoder


searchDecoder : Decoder Search
searchDecoder =
    map2 Search
        (field "pull_request" Decode.int)
        (field "title" string)


resultDecoder : Decoder Model
resultDecoder =
    map7
        (\pull_request release status title branches searches error ->
            { pull_request = pull_request
            , release = release
            , status = status
            , title = title
            , branches = branches
            , searches = searches
            , error = error
            , loading = False
            , updateStatus = initialModel.updateStatus
            , gcStatus = initialModel.gcStatus
            }
        )
        (field "pull_request" Decode.int)
        (field "release" string)
        (field "status" statusDecoder)
        (field "title" string)
        (field "branches" (list string))
        (field "searches" (list searchDecoder))
        (field "error" string)


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
