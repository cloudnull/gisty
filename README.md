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
