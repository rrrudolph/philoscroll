function handler(event) {
  var request = event.request;
  var host = request.headers.host.value.toLowerCase();
  var parts = host.split(".");
  var app = parts.length > 2 ? parts[0] : "_apex";

  if (app === "www") {
    app = "_apex";
  }

  var uri = request.uri;
  if (uri === "/" || uri.endsWith("/")) {
    uri = uri.endsWith("/") ? uri + "index.html" : "/index.html";
  }

  request.uri = "/" + app + uri;
  return request;
}
