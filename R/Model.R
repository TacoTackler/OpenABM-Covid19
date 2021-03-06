SWIG_add_user_network <- add_user_network
SWIG_add_user_network_random <- add_user_network_random
SWIG_delete_network <- delete_network
SWIG_set_app_users <- set_app_users
SWIG_one_time_step <- one_time_step
SWIG_get_network_by_id <- get_network_by_id
SWIG_write_output_files <- write_output_files
SWIG_write_individual_file <- write_individual_file
SWIG_write_trace_tokens <- write_trace_tokens
SWIG_write_transmissions <- write_transmissions
SWIG_write_quarantine_reasons <- write_quarantine_reasons
SWIG_write_occupation_network <- write_occupation_network
SWIG_write_household_network <- write_household_network
SWIG_write_random_network <- write_random_network
SWIG_print_individual <- print_individual
SWIG_utils_n_current <- utils_n_current
SWIG_utils_n_daily <- utils_n_daily
SWIG_utils_n_daily_age <- utils_n_daily_age
SWIG_utils_n_total <- utils_n_total
SWIG_utils_n_total_age <- utils_n_total_age
SWIG_utils_n_total_by_day <- utils_n_total_by_day
SWIG_calculate_R_instanteous <- calculate_R_instanteous
SWIG_seed_infect_by_idx <- seed_infect_by_idx

#' R6Class Model
#'
#' @description
#' Wrapper class for the \code{model} C struct (\emph{model.h}).
#'
#' @details
#' Model used for running the simulation. Initialise the model by creating
#' a \code{\link{Parameters}} instance.
#'
#' @seealso \code{\link{Parameters}}
#' @seealso \code{\link{AgeGroupEnum}}
#' @seealso \code{\link{SAFE_UPDATE_PARAMS}}
#' @seealso \code{\link{NETWORK_CONSTRUCTIONS}}
Model <- R6Class( classname = 'Model', cloneable = FALSE,

  private = list(
    params_object = NA,

    is_running = FALSE,

    nosocomial = FALSE,

    c_params = NA,

    c_model = NA,

    utils_n_guess = function(key, ...) {
      if (startsWith(key, 'total_')) {
        if (all(!endsWith(key, names(AgeGroupEnum)))) {
          return(private$utils_n_total(...))
        } else {
          return(private$utils_n_total_age(...))
        }
      } else if (startsWith(key, 'daily_')) {
        if (all(!endsWith(key, names(AgeGroupEnum)))) {
          return(private$utils_n_daily(...))
        } else {
          return(private$utils_n_daily_age(...))
        }
      }
      stop('Unable to guess which function to use for: ', key)
    },

    utils_n_current = function(enums) {
      f <- function(enum) {
        return(SWIG_utils_n_current( private$c_model, enum ))
      }
      return(sum(sapply(enums,f)))
    },

    utils_n_daily = function(enums, time = NA) {
      if (is.na(time)) { time <- private$c_model$time }
      f <- function(enum) {
        return(SWIG_utils_n_daily( private$c_model, enum, time ))
      }
      return(sum(sapply(enums,f)))
    },

    utils_n_daily_age = function(enums, age, time = NA) {
      if (is.na(time)) { time <- private$c_model$time }
      f <- function(enum) {
        return(SWIG_utils_n_daily_age( private$c_model, enum, time, age ))
      }
      return(sum(sapply(enums,f)))
    },

    utils_n_total = function(enums) {
      f <- function(enum) {
        return(SWIG_utils_n_total( private$c_model, enum ))
      }
      return(sum(sapply(enums,f)))
    },

    utils_n_total_age = function(enums, age) {
      f <- function(enum) {
        return(SWIG_utils_n_total_age( private$c_model, enum, age ))
      }
      return(sum(sapply(enums,f)))
    },

    utils_n_total_by_day = function(enums, time = NA) {
      if (is.na(time)) { time <- private$c_model$time }
      f <- function(enum) {
        return(SWIG_utils_n_total_by_day( private$c_model, enum, time ))
      }
      return(sum(sapply(enums,f)))
    },

    calculate_R_instanteous = function(percentile, time = NA) {
      if (is.na(time)) { time <- private$c_model$time }
      return(SWIG_calculate_R_instanteous( private$c_model, time, percentile ))
    }
  ),

  public = list(
    #' @param params_object An object of type \code{\link{Parameters}}. The
    #' constructor will lock the parameter values (ie. \code{params_code}
    #' will become read-only).
    initialize = function(params_object)
    {
      if (!is.R6(params_object)) {
        stop("params_object is an a Parameters R6Class")
      }
      # Store the params object so it doesn't go out of scope and get freed
      private$params_object <- params_object
      # Create C parameters object
      private$c_params   <- params_object$return_param_object()
      private$c_model    <- create_model(private$c_params)
      private$nosocomial <- as.logical(self$get_param('hospital_on'))
    },

    #' @description Get a parameter value by name
    #' @param param name of param
    #' @return value of stored param
    get_param = function(param)
    {
      enum <- get_base_param_from_enum(param)
      if (!is.null(enum)) {
        # multi-value parameter (C array)
        getter <- get(paste0("get_model_param_", enum$base_name))
        result <- getter( private$c_model, enum$index )
      } else {
        # single-value parameter
        getter <- get(paste0("get_model_param_", param))
        result <- getter( private$c_model )
      }
      return(result)
    },

    #' @description
    #' A subset of parameters may be updated whilst the model is evaluating,
    #' these correspond to events. This function throws an error if
    #' \code{param} isn't safe to update.
    #' @param param name of parameter. See \code{\link{SAFE_UPDATE_PARAMS}} for
    #' allowed parameter names
    #' @param value value of parameter
    update_running_params = function(param, value)
    {
      if (! param %in% SAFE_UPDATE_PARAMS) {
        stop('Cannot update "', param, '" during running')
      }

      enum <- get_base_param_from_enum(param)
      if (!is.null(enum)) {
        # multi-value parameter (C array)
        setter <- get(paste0("set_model_param_", enum$base_name))
        setter( private$c_model, value, enum$index )
      } else {
        # single-value parameter
        setter <- get(paste0("set_model_param_", param))
        setter( private$c_model, value )
      }
    },

    #' @description Gets the value of the risk score parameter.
    #' Wrapper for C API \code{get_model_param_risk_score}.
    #' @param day Infection day
    #' @param age_inf Infector age group index, value between 0 and 8.
    #' See \code{\link{AgeGroupEnum}} list
    #' @param age_sus Susceptible age group index, value between 0 and 8.
    #' See \code{\link{AgeGroupEnum}} list
    #' @return The risk value.
    get_risk_score = function(day, age_inf, age_sus)
    {
      value <- get_model_param_risk_score(
        private$c_model, day, age_inf, age_sus)
      if (value < 0) {
        stop( "Failed to get risk score")
      }
      return(value)
    },

    #' @description Gets the value of the risk score household parameter.
    #' Wrapper for C API \code{get_model_param_risk_score_household}.
    #' @param age_inf Infector age group index, value between 0 and 8.
    #' See \code{\link{AgeGroupEnum}} list
    #' @param age_sus Susceptible age group index, value between 0 and 8.
    #' See \code{\link{AgeGroupEnum}} list
    #' @return The risk value.
    get_risk_score_household = function(age_inf, age_sus)
    {
      value <- get_model_param_risk_score_household(
        private$c_model, age_inf, age_sus)
      if (value < 0) {
        stop( "Failed to get risk score household")
      }
      return(value)
    },

    #' @description
    #' Gets the value of the risk score parameter.
    #' Wrapper for C API \code{set_model_param_risk_score}.
    #' @param day Infection day
    #' @param age_inf Infector age group index, value between 0 and 8.
    #' See \code{\link{AgeGroupEnum}} list
    #' @param age_sus Susceptible age group index, value between 0 and 8.
    #' See \code{\link{AgeGroupEnum}} list
    #' @param value The risk value
    set_risk_score = function(day, age_inf, age_sus, value)
    {
      ret <- set_model_param_risk_score(
        private$c_model, day, age_inf, age_sus, value)
      if (ret == 0) {
        stop( "Failed to set risk score")
      }
    },

    #' @description
    #' Gets the value of the risk score household parameter.
    #' Wrapper for C API \code{set_model_param_risk_score_household}.
    #' @param age_inf Infector age group index, value between 0 and 8.
    #' See \code{\link{AgeGroupEnum}} list
    #' @param age_sus Susceptible age group index, value between 0 and 8.
    #' See \code{\link{AgeGroupEnum}} list
    #' @param value The risk value.
    set_risk_score_household = function(age_inf, age_sus, value)
    {
      ret <- set_model_param_risk_score_household(
        private$c_model, age_inf, age_sus, value)
      if (ret == 0) {
        stop( "Failed to set risk score household")
      }
    },

    #' @description
    #' Adds as bespoke user network from a dataframe of edges
    #' the network is static with the exception of skipping
    #' hospitalised and quarantined people.
    #' Wrapper for C API \code{add_user_network}.
    #' @param df_network Network data frame. List of edges, with 2 columns
    #' \code{ID_1} and \code{ID_2}
    #' @param interaction_type Must 0 (household), 1 (occupation), or 2 (random)
    #' @param skip_hospitalised If \code{TRUE}, skip interaction if either
    #' person is in hospital.
    #' @param skip_quarantine If \code{TRUE}, skip interaction if either person
    #' is in quarantined
    #' @param construction The method used for network construction. Must be a
    #' number between 0 and 4 (inclusive).
    #' See \code{\link{NETWORK_CONSTRUCTIONS}}.
    #' @param daily_fraction The fraction of edges on the network present each
    #' day (i.e. down-sampling the network). Must be a value between 0 and 1.
    #' @param name Name of the network.
    add_user_network = function(
      df_network,
      interaction_type = 1,
      skip_hospitalised = TRUE,
      skip_quarantine = TRUE,
      construction = NETWORK_CONSTRUCTION[['BESPOKE']],
      daily_fraction = 1.0,
      name = "user_network")
    {
      # Validate input
      if (!'ID_1' %in% names(df_network)) {
        stop( "df_network must have column ID_1" )
      }
      if (!'ID_2' %in% names(df_network)) {
        stop( "df_network must have column ID_2" )
      }
      if (!interaction_type %in% c(0,1,2)) {
        stop( "interaction_type must be 0 (household), 1 (occupation) or 2 (random)" )
      }
      if ((daily_fraction > 1) || (daily_fraction < 0)) {
        stop( "daily fraction must be in the range 0 to 1" )
      }
      if (!is.logical(skip_hospitalised)) {
        stop( "skip_hospitalised must be TRUE or FALSE" )
      }
      if (!is.logical(skip_quarantine)) {
        stop( "skip_quarantine must be TRUE or FALSE" )
      }

      n_edges <- nrow(df_network)
      n_total <- private$c_params$n_total
      ID_1 <- df_network[['ID_1']]
      ID_2 <- df_network[['ID_2']]

      # Validate IDs
      for (i in list(ID_1, ID_2)) {
        if ((max(i) >= n_total) || (min(i) < 0)) {
          stop( "all values of ID_1 and ID_2 must be between 0 and n_total-1" )
        }
      }

      SWIG_add_user_network( private$c_model, interaction_type,
        skip_hospitalised, skip_quarantine, daily_fraction, n_edges, ID_1,
        ID_2, name)
    },

    #' @description
    #' Adds a bespoke user random network from a dataframe of people and number
    #' of interactions. The network is regenerates each day, but the number of
    #' interactions per person is static. Hospitalsed and quarantined people
    #' can be skipped
    #' @param df_interactions List of indviduals and interactions. Must be a
    #' dataframe with 2 columns \code{ID} and \code{N}.
    #' @param skip_hospitalised Skip interaction if either person is in
    #' hospital. Must a logical value.
    #' @param skip_quarantine Skip interaction if either person is in
    #' quarantined. Must a logical value.
    #' @param name The name of the network.
    add_user_network_random = function(
      df_interactions,
      skip_hospitalised = TRUE,
      skip_quarantine = TRUE,
      name = "user_network" )
    {

      # Validate input
      if (!'ID' %in% names(df_network)) {
        stop( "df_interactions must have column ID" )
      }
      if (!'N' %in% names(df_network)) {
        stop( "df_interactions must have column N" )
      }
      if (!is.logical(skip_hospitalised)) {
        stop( "skip_hospitalised must be TRUE or FALSE" )
      }
      if (!is.logical(skip_quarantine)) {
        stop( "skip_quarantine must be TRUE or FALSE" )
      }

      n_indiv <- nrow(df_interactions)
      n_total <- private$c_params$n_total
      ID <- df_interactions[['ID']]
      N  <- df_interactions[['N']]

      # Validate ID / N
      if ((max(ID) >= n_total) || (min(ID) < 0)) {
        stop( "all values of ID must be between 0 and n_total-1" )
      }
      if (min(N) < 1) {
        stop( "all values of N must be greater than 0" )
      }

      id <- SWIG_add_user_network_random( private$c_model, skip_hospitalised,
        skip_quarantine, n_indiv, ID, N, name )

      return(Network$new( private$c_model, id ))
    },

    #' @description Get a network.
    #' Wrapper for C API \code{get_network_by_id}.
    #' @param network_id The network ID.
    get_network_by_id = function(network_id)
    {
      return(Network$new( private$c_model, network_id ))
    },

    #' @description Infects a new individual from an external source.
    #' Wrapper for C API \code{seed_infect_by_idx}.
    #' @param ID The ID of the individual.
    #' @param strain_multiplier The strain multiplier value, must be a
    #'   positivate number.
    #' @param network_id The network ID.
    #' @return \code{TRUE} on success, \code{FALSE} otherwise.
    seed_infect_by_idx = function(ID, strain_multiplier = 1, network_id = -1 )
    {
      n_total <- private$c_params$n_total

      if (ID < 0 || ID >= n_total) {
        stop("ID out of range (0<=ID<n_total)")
      }
      if (strain_multiplier < 0) {
        stop("strain_multiplier must be positive")
      }
      res <- SWIG_seed_infect_by_idx(private$c_model, ID, strain_multiplier,
        network_id)
      return(as.logical(res))
    },

    #' @description Get the list of network IDs
    #' Wrapper for C API \code{get_network_ids}.
    #' @param max_ids The maximum number of IDs to return.
    #' @return The list of the network IDs.
    get_network_ids = function(max_ids)
    {
      if (max_ids < 1) return(NA)

      n <- 0
      ids <- rep(NA, max_ids)
      for (offset in 0:(max_ids - 1)) {
        networkid <- get_network_id_by_index( private$c_model, offset );
        if (networkid == -1) {
          break;
        }

        n <- (n + 1)
        ids[n] <- networkid
      }
      return(ids[1:n])
    },

    #' @description Get network info.
    #' @param max_ids The maximum number of rows to return.
    #' @return The network info as a dataframe. The columns are the network
    #' properties and each row is a network.
    get_network_info = function(max_ids = 1000)
    {
      if (max_ids > 1e6) {
        stop("Maximum number of allowed network is 1e6")
      }
      ids <- self$get_network_ids( max_ids )

      if (length(ids) == 1) {
        return(self$get_network_info( max_ids*10 ))
      }

      # Allocate a matrix the correct size
      colnames <- c( 'id', 'name', 'n_edges', 'n_vertices', 'type',
        'skip_hospitalised', 'skip_quarantined', 'daily_fraction')
      tmp <- matrix( data = NA, nrow = length(ids), ncol = 8,
        dimnames = list(NULL,colnames))

      # Initialise each row one-by-one
      for (i in 1:length(ids)) {
        c_network <- SWIG_get_network_by_id( private$c_model, ids[i] )
        tmp[i,] <- c(
          ids[i],
          network_name( c_network ),
          network_n_edges( c_network ),
          network_n_vertices( c_network ),
          network_type( c_network ),
          network_skip_hospitalised( c_network ),
          network_skip_quarantined( c_network ),
          network_daily_fraction( c_network ))
      }

      return(as.data.frame(tmp))
    },

    #' @description Vaccinate an individual.
    #' Wrapper for C API \code{intervention_vaccinate_by_idx}.
    #' @param ID The ID of the individual (must be \code{0 <= ID <= n_total}).
    #' @param vaccine_type The type of vaccine, see \code{\link{VACCINE_TYPES}}.
    #' @param efficacy Probability that the person is successfully vaccinated
    #'   (must be \code{0 <= efficacy <= 1}).
    #' @param time_to_protect Delay before it takes effect (in days).
    #' @param vaccine_protection_period The duration of the vaccine before it
    #'   wanes.
    #' @return Logical value, \code{TRUE} if vaccinated \code{FALSE} otherwise.
    vaccinate_individual = function(
      ID,
      vaccine_type = 0,
      efficacy = 1.0,
      time_to_protect = 14,
      vaccine_protection_period = 1000 )
    {
      n_total <- private$c_params$n_total

      if (ID < 0 || ID >= n_total) {
        stop("ID out of range (0<=ID<n_total)")
      }
      if (efficacy < 0 || efficacy > 1) {
        stop("efficacy must be between 0 and 1")
      }
      if (time_to_protect < 1) {
        stop("vaccine must take at least one day to take effect")
      }
      if (vaccine_protection_period <= time_to_protect) {
        stop("vaccine must protect for longer than it takes to by effective")
      }
      if (!is.numeric(vaccine_type) || ! vaccine_type %in% VACCINE_TYPES) {
        stop("vaccine type must be listed in VaccineTypesEnum")
      }

      res <- intervention_vaccinate_by_idx(private$c_model, ID, vaccine_type,
        efficacy, time_to_protect, vaccine_protection_period)
      return(as.logical(res))
    },

    #' @description Schedule an age-group vaccionation
    #' Wrapper for C API \code{intervention_vaccinate_age_group}.
    #' @param schedule An instance of \code{\link{VaccineSchedule}}.
    #' @return The total number of people vaccinated.
    vaccinate_schedule = function(schedule)
    {
      if (!is.R6(schedule) || !('VaccineSchedule' %in% class(schedule))) {
        stop("argument VaccineSchedule must be an object of type VaccineSchedule")
      }
      return(as.logical(intervention_vaccinate_age_group(
        private$c_model,
        schedule$fraction_to_vaccinate,
        schedule$vaccine_type,
        schedule$efficacy,
        schedule$time_to_protect,
        schedule$vaccine_protection_period,
        schedule$total_vaccinated)))
    },

    #' @description Delete a network.
    #' Wrapper for C API \code{delete_network}.
    #' @param network The network to delete.
    #' @return \code{TRUE} on success, \code{FALSE} on failure.
    delete_network = function(network)
    {
      res <- SWIG_delete_network( private$c_model, network$c_network )
      return(as.logical(res))
    },

    #' @description Get all app users. Wrapper for C API \code{get_app_users}.
    #' @return All app users.
    get_app_users = function()
    {
      n <- private$c_params$n_total
      users <- integer(n)
      for (i in 1:n) {
        users[i] <- get_app_user_by_index(private$c_model, i - 1)
      }
      IDs <- seq(from = 0, to = n - 1)
      result <- data.frame('ID' = IDs, 'app_user' = users)
      return(result)
    },

    #' @description Sets specific users to have or not have the app.
    #' Wrapper for C API \code{set_app_users}. Throws error on failure.
    #' @param df_app_users A dataframe which includes the names
    #' \code{c("ID", "app_user")}.
    set_app_users = function(df_app_users)
    {
      if (!all(c("ID", "app_user") %in% names(df_app_users))) {
        stop('df_app_user must contain the columns ID and app_user')
      }

      for (b in c(TRUE, FALSE)) {
        # Select users ID where 'app_user' == b
        IDs <- df_app_users[df_app_users[,'app_user'] == b,] [['ID']]
        SWIG_set_app_users(private$c_model, IDs, length(IDs), b)
      }
    },


    #' @description Move the model through one time step.
    #' Wrapper for C API \code{one_time_step}.
    one_time_step = function()
    {
      SWIG_one_time_step(private$c_model)
    },

    #' @description Get the results from one-time step.
    #' @return A vector with names (i.e. dictionary).
    one_time_step_results = function()
    {
      # Get the list of EVENT_TYPES defined by defineEnumeration() in
      # OpenABMCovid19.R (generated by SWIG)
      EVENT_TYPES <- get(".__E___EVENT_TYPES")
      # Assign local variables to enum values (e.g. PRESYMPTOMATIC <- 1)
      for (enum in EVENT_TYPES) {
        name <- names(EVENT_TYPES)[match(enum, EVENT_TYPES)]
        assign( name, enum )
      }
      # Enums values for "hospital_admissions*"  "hospital_to_critical*"
      if (private$nosocomial) {
        general  <- GENERAL
        critical <- CRITICAL
      } else {
        general  <- TRANSITION_TO_HOSPITAL
        critical <- TRANSITION_TO_CRITICAL
      }

      res = c()

      res['time']             <- private$c_model$time
      res['lockdown']         <- private$c_params$lockdown_on
      res['test_on_symptoms'] <- private$c_params$test_on_symptoms
      res['app_turned_on']    <- private$c_params$app_turned_on

      for (l in as.array(list(
        list("total_infected", c(PRESYMPTOMATIC, PRESYMPTOMATIC_MILD, ASYMPTOMATIC)),
        list("total_case",     c(CASE)),
        list("total_death",    c(DEATH)),
        list("daily_death",    c(DEATH)))))
      {
        key   <- l[[1]]
        enums <- l[[2]]

        res[ key ] <- private$utils_n_guess( key, enums )
        for (i in 1:length(AgeGroupEnum)) {
          age.key   <- paste0(key, names(AgeGroupEnum[i]))
          res[ age.key ] <- private$utils_n_guess( key = age.key,
                                                   enum = enums,
                                                   age = AgeGroupEnum[[i]] )
        }
      }

      res["n_presymptom"]               <- private$utils_n_current(c(PRESYMPTOMATIC, PRESYMPTOMATIC_MILD))
      res["n_asymptom"]                 <- private$utils_n_current(ASYMPTOMATIC)
      res["n_quarantine"]               <- private$utils_n_current(QUARANTINED)
      res["n_tests"]                    <- private$utils_n_total_by_day(TEST_RESULT)
      res["n_symptoms"]                 <- private$utils_n_current(c(SYMPTOMATIC, SYMPTOMATIC_MILD))
      res["n_hospital"]                 <- private$utils_n_current(HOSPITALISED)
      res["n_hospitalised_recovering"]  <- private$utils_n_current(HOSPITALISED_RECOVERING)
      res["n_critical"]                 <- private$utils_n_current(CRITICAL)
      res["n_death"]                    <- private$utils_n_current(DEATH)
      res["n_recovered"]                <- private$utils_n_current(RECOVERED)
      res["hospital_admissions"]        <- private$utils_n_daily(general)
      res["hospital_admissions_total"]  <- private$utils_n_total(general)
      res["hospital_to_critical_daily"] <- private$utils_n_daily(critical)
      res["hospital_to_critical_total"] <- private$utils_n_total(critical)

      res['n_quarantine_infected']                <- private$c_model$n_quarantine_infected
      res['n_quarantine_recovered']               <- private$c_model$n_quarantine_recovered
      res['n_quarantine_app_user']                <- private$c_model$n_quarantine_app_user
      res['n_quarantine_app_user_infected']       <- private$c_model$n_quarantine_app_user_infected
      res['n_quarantine_app_user_recovered']      <- private$c_model$n_quarantine_app_user_recovered
      res['n_quarantine_events']                  <- private$c_model$n_quarantine_events
      res['n_quarantine_release_events']          <- private$c_model$n_quarantine_release_events
      res['n_quarantine_events_app_user']         <- private$c_model$n_quarantine_events_app_user
      res['n_quarantine_release_events_app_user'] <- private$c_model$n_quarantine_release_events_app_user

      res["R_inst"]    <- private$calculate_R_instanteous( 0.5 )
      res["R_inst_05"] <- private$calculate_R_instanteous( 0.05 )
      res["R_inst_95"] <- private$calculate_R_instanteous( 0.95 )
      return(res)
    },

    #' @description Write output files.
    #' Wrapper for C API \code{write_output_files}.
    write_output_files = function()
    {
      SWIG_write_output_files(private$c_model, private$c_params)
    },

    #' @description Write output files
    #' Wrapper for C API \code{write_individual_file}.
    write_individual_file = function()
    {
      SWIG_write_individual_file(private$c_model, private$c_params)
    },

    #' @description Wrapper for C API \code{write_interactions}.
    write_interactions_file = function()
    {
      write_interactions(private$c_model)
    },

    #' @description Wrapper for C API \code{write_trace_tokens_ts}.
    #' @param init If \code{TRUE}, overwrite the output file and write the
    #' column names at the start of the file. If \code{FALSE}, append a new
    #' to the output file.
    write_trace_tokens_timeseries = function(init = FALSE)
    {
      if (!is.logical(init)) {
        stop("param init must be TRUE or FALSE")
      }
      write_trace_tokens_ts(private$c_model, as.integer(init))
    },

    #' @description Wrapper for C API \code{write_trace_tokens}.
    write_trace_tokens = function()
    {
      SWIG_write_trace_tokens(private$c_model)
    },

    #' @description Wrapper for C API \code{write_transmissions}.
    write_transmissions = function()
    {
      SWIG_write_transmissions(private$c_model)
    },

    #' @description Wrapper for C API \code{write_quarantine_reasons}.
    write_quarantine_reasons = function()
    {
      SWIG_write_quarantine_reasons(private$c_model, private$c_params)
    },

    #' @description Wrapper for C API \code{write_occupation_network}.
    #' @param idx Network index.
    write_occupation_network = function(idx)
    {
      SWIG_write_occupation_network(private$c_model, private$c_params, idx)
    },

    #' @description Wrapper for C API \code{write_household_network}.
    write_household_network = function()
    {
      SWIG_write_household_network(private$c_model, private$c_params)
    },

    #' @description Wrapper for C API \code{write_random_network}.
    write_random_network = function()
    {
      SWIG_write_random_network(private$c_model, private$c_params)
    },

    #' @description Wrapper for C API \code{print_individual}.
    #' @param idx Individual index.
    print_individual = function(idx)
    {
      SWIG_print_individual(private$c_model, idx)
    }
  )
)
