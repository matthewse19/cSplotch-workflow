# syntax=docker/dockerfile:1

FROM gcr.io/google.com/cloudsdktool/google-cloud-cli:latest


CMD ["/bin/bash"]

WORKDIR /usr

RUN apt-get update && apt-get install -y g++ curl git python3 python3-pip # buildkit
RUN pip3 install git+https://git@github.com/adaly/cSplotch.git # buildkit
RUN git clone https://github.com/adaly/cSplotch.git --recursive # buildkit
RUN git clone https://github.com/stan-dev/cmdstan.git --recursive # buildkit

WORKDIR /usr/cmdstan
RUN make build # buildkit

#update stan syntax
RUN ./bin/stanc --print-canonical /usr/cSplotch/stan/splotch_stan_model.stan > /tmp/splotch_stan_model.stan
RUN ./bin/stanc --print-canonical /usr/cSplotch/stan/comp_splotch_stan_model.stan > /tmp/comp_splotch_stan_model.stan
RUN cp /tmp/splotch_stan_model.stan /usr/cSplotch/stan/splotch_stan_model.stan 
RUN cp /tmp/comp_splotch_stan_model.stan /usr/cSplotch/stan/comp_splotch_stan_model.stan 


RUN make ../cSplotch/stan/splotch_stan_model # buildkit
RUN make ../cSplotch/stan/comp_splotch_stan_model # buildkit
ENV SPLOTCH_BIN=/usr/cSplotch/stan/splotch_stan_model
ENV CSPLOTCH_BIN=/usr/cSplotch/stan/comp_splotch_stan_model
WORKDIR /usr