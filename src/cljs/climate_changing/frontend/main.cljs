(ns climate-changing.frontend.main
  "Application entry point and render-to-DOM scaffolding."
  (:require
   ["maplibre-gl/dist/maplibre-gl.css"]
   [climate-changing.common :as common]
   [climate-changing.frontend.app :as app]
   [climate-changing.frontend.interactive-map :as imap]
   [climate-changing.frontend.state :as state]
   [garden.core :refer [css]]
   [reagent.core :as r]
   [reagent.dom.client :as rdom]))

(defonce root (atom nil))

(defn inject-styles!
  "Compile the garden styles in climate-changing.common and inject them into
  <head>. Called on every hot reload so style edits apply without a refresh."
  []
  (let [style (or (js/document.querySelector "style#climate-changing-styles")
                  (doto (.createElement js/document "style")
                    (.setAttribute "id" "climate-changing-styles")))]
    (when (and (.-head js/document)
               (not (.-parentNode style)))
      (.appendChild (.-head js/document) style))
    (set! (.-textContent style) (css common/default-style))))

(defn ^:dev/after-load re-render []
  (inject-styles!)
  (.render ^js @root (r/as-element [app/app])))

(defn init
  "Runs on application startup and every browser refresh."
  []
  (reset! root (rdom/create-root (js/document.getElementById "app")))
  (imap/set-default-map-style!)
  (re-render)
  (app/fetch-locations!)
  (app/fetch-location-stats!))

(comment
  state/state
  (swap! state/state assoc :message "Hello from the REPL")
  (swap! state/state update :message (fn [x] (str x "!")))
  (swap! state/state update :loading? (fn [x] (not x)))
  (meta #'init)

  (imap/set-globe!)

  ;; clojurescript repl can reach into the browser
  js/document
  (js/alert "hello")
  ;;
  )
