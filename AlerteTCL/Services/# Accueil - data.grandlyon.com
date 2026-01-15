# Accueil - data.grandlyon.com

<!doctype html>
<html lang="fr">

<head>
  <meta charset="utf-8">
  <title>Accueil - data.grandlyon.com</title>
  <meta name="description" content="Les données des acteurs du territoire de la Métropole de Lyon">
  <base href="/portail/fr/">

  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link rel="apple-touch-icon" sizes="180x180" href="./assets/favicons/apple-touch-icon.png">
  <link rel="icon" type="image/png" sizes="32x32" href="./assets/favicons/favicon-32x32.png">
  <link rel="icon" type="image/png" sizes="192x192" href="./assets/favicons/android-chrome-192x192.png">
  <link rel="icon" type="image/png" sizes="16x16" href="./assets/favicons/favicon-16x16.png">
  <link rel="manifest" href="./assets/favicons/site.webmanifest">
  <link rel="mask-icon" href="./assets/favicons/safari-pinned-tab.svg" color="#5bbad5">
  <link rel="shortcut icon" href="./assets/favicons/favicon.ico">
  <meta name="apple-mobile-web-app-title" content="data.grandlyon.com">
  <meta name="application-name" content="data.grandlyon.com">
  <meta name="msapplication-TileColor" content="#242b3f">
  <meta name="msapplication-TileImage" content="./assets/favicons/mstile-144x144.png">
  <meta name="msapplication-config" content="./assets/favicons/browserconfig.xml">
  <meta name="theme-color" content="#242b3f">

  <meta property="og:type" content="website"/>
  <meta property="og:title" content="Accueil - data.grandlyon.com"/>
  <meta property="og:description" content="Les données des acteurs du territoire de la Métropole de Lyon"/>
  <meta property="og:image" content="https://minio.data.grandlyon.com/assets/prod-media-library/2019/12/b43e5989769237ff744a05aeed9209d7-data.grandlyon.jpg"/>

  <link rel="stylesheet" href="https://use.fontawesome.com/releases/v5.5.0/css/all.css" integrity="sha384-B4dIYHKNBt8Bc12p+WXckhzcICo0wtJAoU8YZTY5qE0Id1GSseTk6S+L3BlXeVIU" crossorigin="anonymous">

  <style>
    body {
      margin: 0;
    }

    .AppLoader {
      height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      background-color: #242b3f;
    }

    .AppLoader img {
      width: 60%;
    }

    @media screen and (min-width: 705px) {
      .AppLoader img {
        width: 25%;
      }
    }
  </style>

<link rel="stylesheet" href="styles.9957e066be35fea3c683.css"></head>

<body>
<app-root>
  <section class="AppLoader">
    <img src="assets/img/data_loader.gif" alt="">
  </section>
</app-root>
<script src="runtime-es2015.f776208e48e969c31743.js" type="module"></script><script src="runtime-es5.f776208e48e969c31743.js" nomodule defer></script><script src="polyfills-es5.41bdf357e8d9dcba1eef.js" nomodule defer></script><script src="polyfills-es2015.21c017cf6f4eea0fea2c.js" type="module"></script><script src="scripts.67c7ffafa4109ce3890b.js" defer></script><script src="main-es2015.de796eb56611e471a1ee.js" type="module"></script><script src="main-es5.de796eb56611e471a1ee.js" nomodule defer></script></body>

</html>
