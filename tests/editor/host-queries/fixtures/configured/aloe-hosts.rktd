((file "uses-fs.aloe"
   (host fs-host host/racket/fs fs-interface))
 (file "failing.aloe"
   (host fs-host host/racket/fs no-such-interface)))
