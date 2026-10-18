(ns climate-changing.backend.main
  (:require
   [climate-changing.backend.components]
   [climate-changing.common :as common]
   [integrant.core :as ig])
  (:import [org.slf4j LoggerFactory])
  (:gen-class))

(set! *warn-on-reflection* true)

(def ^:private ^org.slf4j.Logger logger
  (LoggerFactory/getLogger "climate-changing.backend.main"))

(def config
  {:climate-changing/duckdb          {}
   :climate-changing/location-index {}
   :climate-changing/backfill-worker {:location-index (ig/ref :climate-changing/location-index)
                                      :duckdb         (ig/ref :climate-changing/duckdb)}
   :climate-changing/handler         {:location-index (ig/ref :climate-changing/location-index)
                                      :duckdb         (ig/ref :climate-changing/duckdb)}
   :climate-changing/server          {:port    (Integer/parseInt (or (System/getenv "PORT") "8081"))
                                      :handler (ig/ref :climate-changing/handler)}})

(defn -main
  "Start the server and block the main thread."
  [& _args]
  (let [system (ig/init config)]
    (.addShutdownHook (Runtime/getRuntime)
                      (Thread. ^Runnable (fn [] (when system  (ig/halt! system)))))
    (.info logger (str common/appname " started on http://localhost:" (:port (:climate-changing/server config))))
    @(promise)))
