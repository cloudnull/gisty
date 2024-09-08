# Gisty.link

Gisty.link is a platform that allows users to easily share content or gists through a simple link. Users can submit content via a form, which is securely stored in OpenStack Swift, and retrieve it later using a unique URL. The platform is built using Vapor, Swift, and Tailwind CSS, with a GitHub-inspired dark theme.

## Features

- Submit content using a simple form.
- Content is stored in OpenStack Swift with a unique hashed identifier.
- Retrieve content by entering the generated link.
- GitHub-inspired dark theme using Tailwind CSS.
- Responsive design with a dynamic layout.

### Set up environment variables

Ensure you have the following environment variables set for connecting to OpenStack Swift.

> This project uses application credentials, and will require you to setup specific OpenStack
  application credentials before starting. This is done so that your account credentials are
  never used to the operations of this applications and can be revoked or rotated without
  creating an issue with the account itself. Application credential information is loaded into
  the runtime via environment variables. More on application credentials can be found
  [here](https://docs.openstack.org/keystone/latest/user/application_credentials.html).

``` shell
export KEYSTONE_AUTH_URL="your-keystone-auth-url"
export KEYSTONE_APP_ID="your-username"
export KEYSTONE_APP_SECRET="your-password"
export SWIFT_CONTAINER_NAME="gisty"
```

### Building the container

Running the build locally is simple.

``` shell
docker build . -t $USER/gisty
```

> Images are also provided in this repo.

## Starting the service

``` bash
docker run -e KEYSTONE_APP_ID=XXX -e KEYSTONE_AUTH_URL=XXX -e KEYSTONE_APP_SECRET=XXX --network=host $USER/gisty
```

## Accessing the service

Open your browser and navigate to `http://localhost:8080` to access Gisty.link.

### Usage

Access and usage is simple.

#### Submit Content

1. Go to the home page (`/`).
2. Fill out the form with your content.
3. Click "Submit". You will be redirected to a unique link where your content is accessible.

#### Retrieve Content
- Use the unique link provided after submission to access your content.
- RAW content can be accessed by simply accessing the RAW URL.
