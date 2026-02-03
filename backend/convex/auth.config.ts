import { AuthConfig } from "convex/server";

// Firebase Authentication as OIDC provider
// Firebase issues JWT tokens that Convex can validate via this config
export default {
  providers: [
    {
      // Firebase OIDC domain format: https://securetoken.google.com/{PROJECT_ID}
      domain: "https://securetoken.google.com/quickfit-4f71f",
      applicationID: "quickfit-4f71f",
    },
  ],
} satisfies AuthConfig;
