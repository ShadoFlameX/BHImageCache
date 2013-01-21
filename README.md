# BHImageCache
## Basic Image Caching on iOS with support for HTTP Header Expiration

## Instructions
1. Copy BHImageCache.h and BHImageCache.m to your own project.
1. Use the sharedCache instance on BHImageCache to load images via imageWithURL:operationQueue:completionBlock:

Images are stored in the Caches folder for your app and will be removed by the OS when it sees fit. If the http response for the image includes a Expires date then  only the cached image will be used until the expiration is reached. After the expiration the image will be re-downloaded the next time it is fetched. Responses that do not contain an Expires Header will be downloaded every time, but the cache may still be used to support an 'offline' mode.

Responses with an Expires date more than 365 days in the future will be considered invalid and ignored.
