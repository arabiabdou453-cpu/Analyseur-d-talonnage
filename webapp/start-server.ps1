# Serveur local pour la version web : http://localhost:8780
# Lancement : clic droit > Exécuter avec PowerShell, ou double-clic sur start-server.bat.
# Fermez la fenêtre pour arrêter le serveur.
param([int]$Port = 8780)
$Root = $PSScriptRoot
$types = @{ '.html'='text/html; charset=utf-8'; '.css'='text/css; charset=utf-8'; '.js'='application/javascript; charset=utf-8'; '.json'='application/json'; '.csv'='text/csv'; '.pdf'='application/pdf' }
$l = New-Object System.Net.HttpListener
$l.Prefixes.Add("http://localhost:$Port/")
$l.Start()
Write-Host "Analyseur d'etalonnage : http://localhost:$Port  (fermez cette fenetre pour arreter)"
Start-Process "http://localhost:$Port"
while ($l.IsListening) {
  $ctx = $l.GetContext()
  $p = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath.TrimStart('/'))
  if ($p -eq '') { $p = 'index.html' }
  # Mêmes en-têtes de sécurité que vercel.json, pour tester localement dans les conditions de production.
  $ctx.Response.AddHeader('Content-Security-Policy', "default-src 'none'; script-src 'self' https://cdnjs.cloudflare.com; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self'; connect-src 'self' https://cdnjs.cloudflare.com; worker-src blob:; manifest-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'; object-src 'none'")
  $ctx.Response.AddHeader('X-Content-Type-Options', 'nosniff')
  $ctx.Response.AddHeader('Referrer-Policy', 'no-referrer')
  $ctx.Response.AddHeader('Cross-Origin-Opener-Policy', 'same-origin')
  $ctx.Response.AddHeader('Cross-Origin-Embedder-Policy', 'require-corp')
  $ctx.Response.AddHeader('Cross-Origin-Resource-Policy', 'same-origin')
  $f = [IO.Path]::GetFullPath((Join-Path $Root $p))
  if ($f.StartsWith([IO.Path]::GetFullPath($Root)) -and (Test-Path $f -PathType Leaf)) {
    $b = [IO.File]::ReadAllBytes($f)
    $ext = [IO.Path]::GetExtension($f).ToLower()
    if ($types.ContainsKey($ext)) { $ctx.Response.ContentType = $types[$ext] }
    $ctx.Response.OutputStream.Write($b, 0, $b.Length)
  } else { $ctx.Response.StatusCode = 404 }
  $ctx.Response.Close()
}
