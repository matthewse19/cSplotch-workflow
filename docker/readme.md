# Setup

Install [Docker](https://www.docker.com/). 

Install the [Google Cloud CLI](https://cloud.google.com/sdk/docs/install).

Follow [https://wiki.nygenome.org/display/UKB/Google+Container+Registry+-+GCR](https://wiki.nygenome.org/display/UKB/Google+Container+Registry+-+GCR) to login and configure `gcloud`. 

# Clone Image

Clone the image from the Artifact Registry:

```
$ docker pull \
    us-central1-docker.pkg.dev/techinno/images/csplotch_img:latest
```

# Update Existing Image

Build and specify architecture (otherwise default Mac ARM architecture may be used):

```
$ docker build --platform linux/amd64 .
```

Push image:

```
$ docker push gcr.io/techinno/csplotch_img:latest
```

