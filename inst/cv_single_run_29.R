# This file is to compare first trial of predictive performance of spBART and BART
rm(list=ls())
library(dbarts)
library(mlbench)
library(purrr)
library(MOTRbart)
library(doParallel)
library(tidyverse)
source("R/sim_functions_29.R")
source("R/main_function_29.R")
devtools::load_all()


# Simulation arguments
set.seed(42)
n_ <- 250
sd_ <- 1
n_rep_ <- 10

# Selecting a simulated scenarion
# (1): "oned_break" one dimensionnal sin(2*x) with a break
# (2): "friedman_nointer_nonoise": four-dimensional friedmna setting with no interaction terms and no extra X noise variables
# (3): "interaction
# type_ <- c("friedman_break")
type_ <- c("friedman")
# type_ <- "smooth.main.formula"
# type_ <- "non.smooth.main.formula"
# type_ <- "non.and.smooth.main.formula"
# type_ <- 'mlbench.d1.break'
# type_ <- "airquality"
# ================
# Printing message
# ================


cv_ <- vector("list", n_rep_)

# Generating CV_ object
for( i in 1:n_rep_){


  # train <- mlbench.d1.break(n = n_,sd = sd_) %>% as.data.frame()
  # test <- mlbench.d1.break(n = n_,sd = sd_) %>% as.data.frame()

  if(type_ == "smooth.main.formula"){
    train_sim <- sim.gen(n_ = n_,sd_ = sd_,p_ = 10,formula_ = smooth.main.formula)
    test_sim <- sim.gen(n_ = n_,sd_ = sd_,p_ = 10,formula_ = smooth.main.formula)
    train <- data.frame(x = train_sim$x, y = train_sim$y)
    test <- data.frame(x = test_sim$x, y = test_sim$y)
  }

  if(type_ == "non.smooth.main.formula"){
    train_sim <- sim.gen(n_ = n_,sd_ = sd_,p_ = 10,formula_ = non.smooth.main.formula)
    test_sim <- sim.gen(n_ = n_,sd_ = sd_,p_ = 10,formula_ = non.smooth.main.formula)
    train <- data.frame(x = train_sim$x, y = train_sim$y)
    test <- data.frame(x = test_sim$x, y = test_sim$y)
  }

  if(type_ == "non.and.smooth.main.formula"){
    train_sim <- sim.gen(n_ = n_,sd_ = sd_,p_ = 10,formula_ = non.and.smooth.main.formula)
    test_sim <- sim.gen(n_ = n_,sd_ = sd_,p_ = 10,formula_ = non.and.smooth.main.formula)
    train <- data.frame(x = train_sim$x, y = train_sim$y)
    test <- data.frame(x = test_sim$x, y = test_sim$y)
  }

  if(type_ == "friedman_nointer_nonoise"){
    train <- mlbench.friedman1.nointeraction(n = n_,sd = sd_) %>% as.data.frame()
    test <- mlbench.friedman1.nointeraction(n = n_,sd = sd_) %>% as.data.frame()
  }

  if(type_ == "friedman_break"){
    train <- break.mlbench.friedman1(n = n_,sd = sd_) %>% as.data.frame()
    test <- break.mlbench.friedman1(n = n_,sd = sd_) %>% as.data.frame()
  }

  if(type_ == "friedman_nointer_noise"){
    train <- mlbench.friedman1.nointeraction.noise(n = n_,sd = sd_) %>% as.data.frame()
    test <- mlbench.friedman1.nointeraction.noise(n = n_,sd = sd_) %>% as.data.frame()
  }
  # train <- mlbench.friedman1(n = n_,sd = sd_) %>% as.data.frame() %>% .[,c(1:5,11)]
  # test <- mlbench.friedman1(n = n_,sd = sd_) %>% as.data.frame() %>% .[,c(1:5,11)]

  if(type_ == "friedman"){
    train <- mlbench.friedman1(n = n_,sd = sd_) %>% as.data.frame()
    test <- mlbench.friedman1(n = n_,sd = sd_) %>% as.data.frame()
  }

  if(type_ == "friedman_interaction"){
    train <- mlbench.friedman1.interaction.only(n = n_,sd = sd_) %>% as.data.frame()
    test <- mlbench.friedman1.interaction.only(n = n_,sd = sd_) %>% as.data.frame()
  }

  if(type_ == 'mlbench.d1.break'){
    train <- mlbench.d1.break(n = n_,sd = sd_)  |> as.data.frame()
    test <- mlbench.d1.break(n = n_,sd = sd_) |> as.data.frame()
  }

  if(type_ == "airquality"){
    # Setting the data
    airquality <- read_csv("/users/research/mmarques/spline_bart_lab/rspBART27/inst/airquality/airquality.csv")
    # Removing the NA columns
    airquality <- airquality[complete.cases(airquality),]
    # Transforming the data so it is aligned with the Bayesian MARS paper
    data_ <- airquality %>% dplyr::select(Ozone,Solar.R,Wind,Temp) %>% dplyr::mutate(Ozone = (Ozone)^(1/3)) %>% dplyr::rename(y = Ozone)
    train <- data_

    # Creating a fine grid for the test
    rad_grid <- seq(min(data_$Solar.R)*0.9,max(data_$Solar.R)*0.9, length.out = 25)
    temp_grid <- seq(min(data_$Temp)*0.9, max(data_$Temp)*0.9, length.out = 25)
    wind_grid <- seq(min(data_$Wind)*0.9, max(data_$Wind)*0.9, length.out = 25)
    grid_temp_wind <- expand.grid(wind_grid,temp_grid)
    rad_rand <- runif(n = nrow(grid_temp_wind),min = 0.9* min(data_$Solar.R),
                      max = 0.9*max(data_$Solar.R))

    y_test_random <- rnorm(n = nrow(grid_temp_wind))
    test <- data.frame(y_test_random,rad_rand,grid_temp_wind)
    colnames(test) <- colnames(train)
  }

  cv_[[i]]$train <- train
  cv_[[i]]$test <- test
}

# ======
# Setting the single model to be generated here.
# ======
selected_rep_ <- 1
selected_train <- cv_[[selected_rep_]]$train
selected_test <- cv_[[selected_rep_]]$test
sim_train <- selected_test
sim_test <- selected_test
# Defining the default parameters that are going to be used in the model, in this case I putting all
#of them as the same from function arguments to make it easier to save it.
x_train <- selected_train[,colnames(sim_train)!="y"]
x_test <- selected_test[,colnames(sim_train)!="y"]
y_train <- selected_train$y
y_test <- selected_test$y
n_tree <- 10
n_mcmc <- 5000
n_burn <- 3000
alpha <- 0.5
beta <- 2
df <- 3
sigquant <- 0.9
kappa <- 2
nIknots <- 20
node_min_size <- 25

dif_order <- 2
tau <- 1
scale_bool <- TRUE
stump <- FALSE
numcut <- 100
usequants <- FALSE
motrbart_bool <- FALSE
use_bs <- FALSE
plot_preview <- FALSE
all_var <- FALSE
scale_init <- FALSE
update_tau_beta <- TRUE
main_effects_pred <- TRUE
interaction_term <- TRUE
interaction_list <- NULL
store_tree_fit <- FALSE
mle_prior <- FALSE
linero_sampler <- FALSE
use_D_bool <- FALSE
varimportance_bool <- TRUE
seed_ <- 42
scale_basis_function <- FALSE
robust_prior <- FALSE
eta <- 1e-6
a_delta <- 100
d_delta <- 10
pen_basis <- TRUE

set.seed(seed_)

print(paste0("N: ",n_," SD: ", sd_, " nIknots: ", nIknots,
             " Ntree: ",n_tree, " Seed: ",seed_, " Alpha:", alpha,
             "Update \tau_\beta: ", update_tau_beta, " Dif.Order:",
             dif_order, "_type_", type_, "_nmcmc_", n_mcmc, "_nburn_",n_burn,
             "\n _df_", df, "_a_delta_",a_delta, "_d_delta_", d_delta ))

print(paste0("Node Min size: ", node_min_size))

rsp_mod <- rspBART(x_train = x_train,
                   y_train = y_train,
                   x_test = x_test,
                   n_tree = n_tree,
                   node_min_size = node_min_size,
                   n_mcmc = n_mcmc,n_burn = n_burn,
                   alpha = alpha,beta = beta,
                   df = df,sigquant = sigquant,
                   kappa = kappa,nIknots = nIknots,
                   dif_order = dif_order,tau = tau,
                   scale_bool = scale_bool,stump = stump,
                   numcut = numcut,usequants = usequants,
                   motrbart_bool = motrbart_bool,use_bs = use_bs,
                   plot_preview = plot_preview,
                   all_var = all_var,scale_init = scale_init,
                   update_tau_beta = update_tau_beta,
                   main_effects_pred = main_effects_pred,
                   interaction_term = interaction_term,
                   interaction_list = interaction_list,
                   store_tree_fit = store_tree_fit,
                   linero_sampler = linero_sampler,
                   use_D_bool = use_D_bool,
                   varimportance_bool = varimportance_bool,
                   scale_basis_function = scale_basis_function,
                   a_delta = a_delta,d_delta = d_delta,
                   robust_prior = robust_prior,eta = eta,pen_basis = pen_basis)





# saveRDS(object = rsp_mod,file = paste0("/users/research/mmarques/spline_bart_lab/preliminar_results/rspBART27/",type_,"/single_run/v31_grid2_single_run_rep_",
#                                        selected_rep_,"_n_",n_,
#                                       "_sd_",sd_,"_nIknots_",nIknots,"_ntree_",n_tree,"_nodesize_",node_min_size,
#                                       "_dif_",dif_order,"_scale_",scale_bool,"_sc_basis_",scale_basis_function,
#                                       "_nmcmc_",n_mcmc,"_nburn_",n_burn,"_rb_prior_",robust_prior,"_bpen_",pen_basis,".Rds"))
