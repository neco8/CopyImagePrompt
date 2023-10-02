port module Main exposing (main)

import Browser
import Html exposing (Html, button, div, input, label, span, text, textarea, ul)
import Html.Attributes exposing (checked, class, id, placeholder, rows, tabindex, type_, value)
import Html.Events exposing (onClick, onInput, preventDefaultOn)
import Json.Decode
import Process exposing (sleep)
import Task


type BeforeOrAfter
    = Before
    | After


type ImageType
    = NoteHeader
    | ApplicationMockup
    | ApplicationIcon


type Msg
    = NoOp
    | InputJSON String
    | InputTheme String
    | ToggleCollapse
    | InputReplacer Int BeforeOrAfter String
    | OnClickCopyButton Int String
    | OnClickCopyImagePromptButton ImageType
    | AddToast { milliseconds : Float, toastStr : String }
    | DeleteToast Int
    | OnPaste String
    | PasteToJsonInput
    | AddReplacer
    | DeleteReplacer Int


noop : a -> ( a, Cmd msg )
noop model =
    ( model, Cmd.none )


andThen : (a -> ( b, Cmd msg )) -> ( a, Cmd msg ) -> ( b, Cmd msg )
andThen a ( model, cmd0 ) =
    let
        ( nextModel, cmd1 ) =
            a model
    in
    ( nextModel, Cmd.batch [ cmd0, cmd1 ] )


addToast : Float -> String -> { a | toastModels : List ToastModel } -> ( { a | toastModels : List ToastModel }, Cmd Msg )
addToast milliseconds toastStr model =
    let
        newToastId =
            getNewToastId model.toastModels
    in
    ( { model
        | toastModels =
            { id = newToastId
            , toastStr = toastStr
            }
                :: model.toastModels
      }
    , sleep milliseconds
        |> Task.andThen (always (Task.succeed (DeleteToast newToastId)))
        |> Task.perform identity
    )


updateReplacers : Int -> BeforeOrAfter -> String -> List { a | before : String, after : String } -> List { a | before : String, after : String }
updateReplacers index beforeOrAfter str replacers =
    let
        updateReplacer replacer s =
            case beforeOrAfter of
                Before ->
                    { replacer | before = s }

                After ->
                    { replacer | after = s }
    in
    List.indexedMap
        (\i a ->
            if i == index then
                updateReplacer a str

            else
                a
        )
        replacers


updateRaw : Msg -> Model -> ( Model, Cmd Msg )
updateRaw msg model =
    case msg of
        NoOp ->
            noop model

        OnClickCopyButton index str ->
            ( model, Cmd.none )
                |> andThen (\prev -> ( prev, copy str ))
                |> andThen (addToast 2000 ("Midjourney Prompt " ++ (String.fromInt <| index + 1) ++ " is copied!"))
                |> andThen (\prev -> ( { prev | copiedIndices = index :: prev.copiedIndices }, Cmd.none ))

        InputJSON str ->
            ( { model | jsonInput = str }, Cmd.none )

        InputTheme str ->
            ( { model
                | themeInput = str
              }
            , Cmd.none
            )

        InputReplacer index beforeOrAfter str ->
            ( { model | replacers = updateReplacers index beforeOrAfter str model.replacers }, Cmd.none )

        AddToast { milliseconds, toastStr } ->
            addToast milliseconds toastStr model

        DeleteToast id ->
            ( { model
                | toastModels =
                    model.toastModels
                        |> List.filter
                            (\toast ->
                                toast.id /= id
                            )
              }
            , Cmd.none
            )

        PasteToJsonInput ->
            ( model, paste jsonInputId )

        OnPaste str ->
            ( { model | jsonInput = str }, Cmd.none )

        AddReplacer ->
            ( { model | replacers = model.replacers ++ [ { before = "", after = "" } ] }, Cmd.none )

        DeleteReplacer index ->
            ( { model
                | replacers =
                    model.replacers
                        |> List.indexedMap
                            (\i a ->
                                if i == index then
                                    Nothing

                                else
                                    Just a
                            )
                        |> List.filterMap identity
              }
            , Cmd.none
            )

        ToggleCollapse ->
            ( { model | collapsed = not model.collapsed }, Cmd.none )

        OnClickCopyImagePromptButton imageType ->
            let
                imagePrompt =
                    (case imageType of
                        NoteHeader ->
                            getNoteHeaderImagePrompt

                        ApplicationMockup ->
                            getApplicationMockupImagePrompt

                        ApplicationIcon ->
                            getApplicationIconImagePrompt
                    )
                        model.themeInput
            in
            ( model, copy imagePrompt )
                |> andThen
                    (addToast 2000
                        ((case imageType of
                            NoteHeader ->
                                "Note Header"

                            ApplicationMockup ->
                                "Application Mockup"

                            ApplicationIcon ->
                                "Application Icon"
                         )
                            ++ " prompt copied!"
                        )
                    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        ( updatedModel, updatedCmd ) =
            updateRaw msg model
    in
    ( updatedModel
        |> resetCopiedIndices model
    , updatedCmd
    )


type alias ToastModel =
    { id : Int
    , toastStr : String
    }


getNewToastId : List { a | id : number } -> number
getNewToastId =
    List.map .id
        >> List.maximum
        >> Maybe.map (\x -> x + 1)
        >> Maybe.withDefault 0


type alias Model =
    { jsonInput : String
    , themeInput : String
    , collapsed : Bool
    , toastModels : List ToastModel
    , replacers : List { before : String, after : String }
    , copiedIndices : List Int
    }


resetCopiedIndices :
    { model | jsonInput : String, copiedIndices : List Int, replacers : c }
    -> { model | jsonInput : String, copiedIndices : List Int, replacers : c }
    -> { model | jsonInput : String, copiedIndices : List Int, replacers : c }
resetCopiedIndices before after =
    if before.jsonInput /= after.jsonInput then
        { after | copiedIndices = [] }

    else if before.replacers /= after.replacers then
        { after | copiedIndices = [] }

    else
        after


init : () -> ( Model, Cmd Msg )
init () =
    ( { jsonInput = ""
      , themeInput = ""
      , collapsed = False
      , toastModels = []
      , replacers =
            [ { before = "--v 5.2.", after = "--v 5.2" }
            , { before = "📷 ", after = "" }
            ]
      , copiedIndices = []
      }
    , Cmd.none
    )


copyButtonView : { a | copied : Bool, index : Int, str : String } -> Html Msg
copyButtonView props =
    button
        [ class "btn"
        , if props.copied then
            class "btn-secondary"

          else
            class "btn-primary"
        , onClick (OnClickCopyButton props.index props.str)
        ]
        [ text ("Copy Image Prompt " ++ String.fromInt (props.index + 1)) ]


buttonsView : { a | replacers : List { b | before : String, after : String }, jsonInput : String, copiedIndices : List Int } -> Html Msg
buttonsView props =
    let
        replacer start =
            List.foldl (\a -> String.replace a.before a.after) start props.replacers

        result =
            Result.map
                (List.map
                    (replacer
                        >> (\s -> "/imagine prompt:" ++ s)
                    )
                )
            <|
                Json.Decode.decodeString (Json.Decode.list Json.Decode.string) props.jsonInput
    in
    case result of
        Ok as_ ->
            div
                [ class "grid grid-flow-row gap-2"
                ]
            <|
                List.indexedMap
                    (\i a -> copyButtonView { str = a, index = i, copied = List.member i props.copiedIndices })
                    as_

        Err e ->
            div [ class "rounded-lg p-6 border-collapse bg-red-100 text-red-700" ]
                [ div [ class "" ]
                    [ text <| Json.Decode.errorToString e
                    ]
                ]


replacersView : { a | replacers : List { b | before : String, after : String } } -> Html Msg
replacersView props =
    div [ class "grid grid-flow-row gap-4 p-6 rounded-lg border border-slate-200" ] <|
        label [ class "text-sm text-slate-600" ] [ text "Replacers" ]
            :: List.indexedMap
                (\index a ->
                    div [ class "grid grid-flow-col grid-cols-[1fr,auto] gap-4" ]
                        [ div [ class "grid grid-flow-col gap-4" ]
                            [ input
                                [ class "input input-bordered"
                                , value a.before
                                , onInput (InputReplacer index Before)
                                ]
                                []
                            , input
                                [ class "input input-bordered"
                                , value a.after
                                , onInput (InputReplacer index After)
                                ]
                                []
                            ]
                        , button [ class "btn btn-square btn-outline", onClick (DeleteReplacer index) ] [ text "x" ]
                        ]
                )
                props.replacers
            ++ [ button [ class "btn btn-outline", onClick AddReplacer ] [ text "add replacer" ]
               ]


textareaView : { a | class : String, placeholder : String, value : String, onInput : String -> msg, id : String, rows : Int } -> Html msg
textareaView props =
    textarea
        [ class "textarea textarea-bordered"
        , if String.isEmpty props.class then
            class ""

          else
            class props.class
        , placeholder props.placeholder
        , value props.value
        , onInput props.onInput
        , id props.id
        , rows props.rows
        ]
        []


toastsView : List ToastModel -> Html Msg
toastsView toastModels =
    div
        [ class "toast toast-top toast-end z-[2]"
        ]
    <|
        List.map
            (\toast ->
                div
                    [ class "alert alert-info"
                    , onClick (DeleteToast toast.id)
                    ]
                    [ text toast.toastStr ]
            )
        <|
            toastModels


jsonInputId : String
jsonInputId =
    "jsonInput"


view : Model -> Html Msg
view model =
    div [ class "grid gap-8 p-10" ]
        [ div [ class "collapse rounded-lg bg-slate-100 overflow-visible" ]
            [ input
                [ class "hover:cursor-pointer"
                , type_ "radio"
                , checked <| not model.collapsed
                , preventDefaultOn "click" (Json.Decode.succeed ( ToggleCollapse, False ))
                ]
                []
            , div [ class "collapse-title px-6 py-4 text-slate-600" ] [ text "ThemeからImage Promptを生成するためのPrompt" ]
            , div [ class "form-control collapse-content px-6" ]
                [ label [ class "label" ] [ span [ class "label-text text-slate-600" ] [ text "Theme" ] ]
                , div [ class "join" ]
                    [ input
                        [ class "input input-bordered w-full join-item"
                        , value model.themeInput
                        , onInput InputTheme
                        , placeholder "theme:"
                        , preventDefaultOn "click" (Json.Decode.succeed ( NoOp, False ))
                        ]
                        []
                    , div [ class "dropdown dropdown-hover dropdown-bottom dropdown-end" ]
                        [ label [ tabindex 0, class "btn join-item btn-outline" ] [ text "generate" ]
                        , ul [ tabindex 0, class "dropdown-content z-[1] menu p-2 shadow bg-base-100 rounded-box" ]
                            [ button
                                [ onClick (OnClickCopyImagePromptButton NoteHeader)
                                , class "btn btn-ghost whitespace-nowrap justify-start"
                                ]
                                [ text "note header" ]
                            , button
                                [ onClick (OnClickCopyImagePromptButton ApplicationMockup)
                                , class "btn btn-ghost whitespace-nowrap justify-start"
                                ]
                                [ text "application mockup" ]
                            , button
                                [ onClick (OnClickCopyImagePromptButton ApplicationIcon)
                                , class "btn btn-ghost whitespace-nowrap justify-start"
                                ]
                                [ text "application icon" ]
                            ]
                        ]
                    ]
                ]
            ]
        , replacersView model
        , button [ class "btn btn-outline", onClick PasteToJsonInput ] [ text "paste image prompts as json" ]
        , textareaView
            { placeholder = "Image Prompts as JSON format. ✍"
            , value = model.jsonInput
            , onInput = InputJSON
            , id = jsonInputId
            , rows = 10
            , class = "p-6"
            }
        , buttonsView model
        , toastsView model.toastModels
        ]


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ onPaste OnPaste
        ]


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }



-----


getNoteHeaderImagePrompt : String -> String
getNoteHeaderImagePrompt theme =
    """ChatGPT, here's a detailed task I need you to execute based on the theme "<Theme>":

Understanding <Theme>: First, grasp the essence of "<Theme>". It's crucial that you understand this correctly, as it's the foundation for the following tasks.

Sketch Ideas: Next, using <Theme> as a basis, I'd like you to conceptualize 10 abstract symbols or designs that can express or represent it. I'm looking for just brief textual descriptions of these symbols or ideas, not actual sketches.

Random Selection: Once you have those 10 ideas, randomly choose 3 out of them. It's essential that this selection is random, so do not prioritize any particular concept.

Photorealistic Plugin Integration: For these 3 selected ideas, use the photorealistic plugin to generate prompts for midjourney. Here's a VERY important note for the plugin: Set the parameters to '--v 5.2' NOT '--v 5.1' and '--ar 1920:1006' NOT '--ar 16:9'. Please, I can't stress this enough. Make sure the plugin gets this right, even if you need to emphasize it multiple times. Misinterpretation of these parameters can lead to undesirable results.

Output in JSON: Finally, the generated prompts from the plugin should be presented as an array of strings in JSON format. This means, your output should look something like: ["...", "...", "...", ...].

Please, execute the above steps with utmost precision. Any deviation or misunderstanding can impact the final output.
---
<Theme>
""" ++ theme


getApplicationIconImagePrompt : String -> String
getApplicationIconImagePrompt theme =
    """https://docs.midjourney.com/docs/parameter-list
Refer to the description of `--quality 1`, `--style raw` and `--ar foo:bar` on the above site, and do the following.
---
Hello ChatGPT, based on the theme '<Theme>', please do the following:

[INSTRUCTIONS]
1. Propose 10 textual descriptions for application icons that embody the essence of '<Theme>'.
2. From those 10 proposals, randomly select 3 descriptions.
3. Explain in detail how to generate clean modern simple application icons and the features required when making application icons into midjourney prompt.
4. Generate midjourney prompts for each of the 3 selected descriptions for WHITE BACKGROUND APPLICATION ICON.

[RESTRICTIONS]
Please remember and it's crucial: set the parameters to '--v 5.2' and '--ar 1:1' and '--style raw'.
I emphasize: use '--v 5.2', not '--v 5.1', and use '--ar 1:1', not '--ar 16:9'.
It's very important to get this right, so please ensure you set the parameters as '--v 5.2' and '--ar 1:1'.
Provide the generated prompts in a JSON format as an array of strings. Ensure it's not an array of objects.
Use the Midjourney to generate stunning images. A more descriptive prompt is better for a unique look. Concentrate on the main concepts you want to create.
Generate an image prompt with care so that the MODERN SIMPLE APPLICATION ICON is generated from [INSTRUCTION 3].
Instead of saying adjective `generate modern simple application icon` describe the IMAGE ITSELF in a detailed language.
---
<Theme>
""" ++ theme


getApplicationMockupImagePrompt : String -> String
getApplicationMockupImagePrompt theme =
    """Dear ChatGPT, I would like you to assist me in creating some text descriptions for a mockup mobile application page based on the <Theme>. Please follow these steps:

1. Propose 10 text suggestions that describe a mobile mockup page representing the <Theme>. These descriptions should be influenced by:
- A bright color palette with contrasting dark colors and a specific highlight color.
- A modern sans-serif font style with readable font size.
- Buttons and icons with a soft rounded shape.
- Strategically placed images or illustrations, either full-screen or sectioned.
- A clean mobile layout.

2. From the 10 suggestions, randomly select 3.

3. With these 3 selected descriptions, use the photorealistic plugin to generate prompts for midjourney. Remember, and I emphasize for clarity: 
- For midjourney use the parameter '--v 5.2' NOT '--v 5.1'. 
- For midjourney use the parameter '--ar 2:3' NOT '--ar 16:9'. 
- Prompt must be super simple and clean in English, not complecated.
- Medium must be super simple.
This is very crucial as the photorealistic plugin tends to get confused.

4. Convert the generated results into a JSON format as a string array, like so: ["...", "...", "...", ...]. Avoid creating an array of objects.
---
<Theme>
""" ++ theme



-----


port copy : String -> Cmd msg


port paste : String -> Cmd msg


port onPaste : (String -> msg) -> Sub msg
