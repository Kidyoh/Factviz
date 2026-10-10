# Build from the repository root so the shared core package is available:
#   docker build -f server/Dockerfile -t factviz-server .
FROM dart:stable AS build
WORKDIR /src
# The pub workspace references the Flutter app, which this image can't
# resolve, so build the server as a standalone package.
COPY packages/factviz_core packages/factviz_core
COPY server server
RUN sed -i '/^resolution: workspace/d' packages/factviz_core/pubspec.yaml server/pubspec.yaml
WORKDIR /src/server
RUN dart pub get && dart compile exe bin/server.dart -o /server

FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /server /app/server
ENV PORT=8080
EXPOSE 8080
CMD ["/app/server"]
