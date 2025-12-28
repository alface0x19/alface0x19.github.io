---
layout: home
title: Home
---
<link rel="stylesheet" href="{{ '/assets/css/index.css' | relative_url }}">

<div class="index-main">
<section class="index-content" markdown="1">
![alt]({{ site.baseurl }}/assets/images/index/icon.png){:class="index-logo"}

👋 Bem-vindo ao alface0x19.

Notas técnicas, tutoriais práticos e decisões reais em Linux, DevOps, homelab e segurança.

📺 Conteúdo complementar em vídeo no YouTube:
[youtube.com/@alface0x19](https://youtube.com/@alface0x19)

</section>
    
<aside class="index-sitemap">
    <h2>Últimos artigos</h2>
    <ul>
    {% for post in site.posts limit:5 %}
    <li>
        <a href="{{ post.url | relative_url }}">{{ post.title }}</a>
        <br>
        <small>{{ post.date | date: "%d-%m-%Y" }}</small>
    </li>
    {% endfor %}
    </ul>
    <a href="{{ '/sitemap' | relative_url }}">Ver todos os artigos →</a>
</aside>