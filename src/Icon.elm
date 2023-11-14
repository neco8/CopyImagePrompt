module Icon exposing (..)

import Html exposing (span, text)
import Html.Attributes exposing (class)


type IconType
    = Menu
    | Close
    | MoreVert
    | Settings


iconTypeToString t =
    case t of
        Menu ->
            "menu"

        Close ->
            "close"

        MoreVert ->
            "more_vert"

        Settings ->
            "settings"


iconView props =
    span
        [ class "material-symbols-rounded"
        , props.class
        ]
        [ text <| iconTypeToString props.iconType ]
