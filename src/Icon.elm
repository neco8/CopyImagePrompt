module Icon exposing (..)

import Html exposing (span, text)
import Html.Attributes exposing (class)


type IconType
    = Menu
    | Close
    | MoreVert


iconTypeToString t =
    case t of
        Menu ->
            "menu"

        Close ->
            "close"

        MoreVert ->
            "more_vert"


iconView props =
    span
        [ class "material-symbols-rounded"
        , props.class
        ]
        [ text <| iconTypeToString props.iconType ]
