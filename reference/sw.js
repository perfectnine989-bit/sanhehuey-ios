const CACHE='sanhehuey-v999';

self.addEventListener(
  'install',
  function(event){
    self.skipWaiting();
  }
);

self.addEventListener(
  'activate',
  function(event){

    event.waitUntil(

      caches.keys()

        .then(function(keys){

          return Promise.all(

            keys.map(function(key){

              if(key!==CACHE){
                return caches.delete(key);
              }

              return Promise.resolve();
            })

          );
        })

        .then(function(){

          return self.clients.claim();

        })

    );
  }
);

self.addEventListener(
  'fetch',
  function(event){

    var request=
      event.request;

    if(request.method!=='GET'){
      return;
    }

    var url=
      new URL(request.url);

    if(
      url.origin
      !==
      self.location.origin
    ){
      return;
    }

    /*
      Картинки/медиа — отдаём браузеру напрямую,
      SW не вмешивается (IMG_PASSTHROUGH_V1).
    */


    /*
      API никогда не кэшируем.
    */

    if(
      url.pathname.indexOf(
        '/api/'
      )===0
    ){
      event.respondWith(
        fetch(request)
      );

      return;
    }

    /*
      HTML/navigation — всегда сеть первой.
    */

    if(
      request.mode==='navigate'
      ||
      url.pathname==='/'
      ||
      url.pathname==='/index.html'
    ){

      event.respondWith(

        fetch(
          request,
          {
            cache:'no-store'
          }
        )

          .then(function(response){

            return response;

          })

          .catch(function(){

            return caches.match(
              request
            );

          })

      );

      return;
    }

    /*
      Остальная статика:
      network first + fallback cache.
    */

    event.respondWith(

      fetch(request)

        .then(function(response){

          if(
            response
            &&
            response.ok
          ){

            var copy=
              response.clone();

            caches.open(CACHE)

              .then(function(cache){

                cache.put(
                  request,
                  copy
                );

              });
          }

          return response;
        })

        .catch(function(){

          return caches.match(
            request
          );

        })

    );
  }
);

/* CLEAN_ROULETTE_V16_9 */

// CASINO_MOTION_V16_9_1

// CS_CASE_MOTION_V16_9_2

// ROULETTE_ENGINE_V17

// ROULETTE_ENGINE_V17_1

// ROULETTE_ENGINE_V17_1_1


/* SANHEHUEY_PWA_PUSH_V18_3_2 */
self.addEventListener('push', function(event){
  var data={};
  try{data=event.data?event.data.json():{};}catch(e){try{data={body:event.data?event.data.text():''};}catch(_){data={};}}
  var title=data.title||'SanHeHuey';
  var options={
    body:data.body||'',
    icon:'/icons/icon-192.png',
    badge:'/icons/icon-192.png',
    tag:data.tag||'sanhehuey',
    renotify:false,
    data:{url:data.url||'/'},
  };
  event.waitUntil(self.registration.showNotification(title,options));
});
self.addEventListener('notificationclick',function(event){
  event.notification.close();
  var url=(event.notification.data&&event.notification.data.url)||'/';
  event.waitUntil(self.clients.matchAll({type:'window',includeUncontrolled:true}).then(function(list){
    for(var i=0;i<list.length;i++){var client=list[i];if('focus'in client){client.navigate(url).catch(function(){});return client.focus();}}
    if(self.clients.openWindow)return self.clients.openWindow(url);
  }));
});

// SANHEHUEY_HQ_EMOJI_ANDROID_V18_3_3
