---
layout: single
title: Podcast
permalink: /podcast/
author_profile: false
---

{% assign podcast_posts = site.posts | where_exp: "post", "post.audio_url != nil and post.audio_url != ''" %}

<div class="post">
  <h1>{{ page.title }}</h1>
  <p>Arquivo dos episódios publicados no site, com player embutido e links para o feed RSS do podcast.</p>
  <p><a href="{{ '/podcast.xml' | relative_url }}">Subscrever via RSS</a></p>

  {% if podcast_posts.size > 0 %}
  <div class="podcast-list">
    {% for post in podcast_posts %}
    <a class="podcast-list__item" href="{{ post.url | relative_url }}">
      <h2 class="podcast-list__title">{{ post.title }}</h2>
      <p class="podcast-list__meta">
        {{ post.date | date: "%d %b %Y" }}
        {% if post.audio_duration %} · {{ post.audio_duration }}{% endif %}
        {% if post.episode_number %} · Episódio {{ post.episode_number }}{% endif %}
      </p>
      {% if post.podcast_summary %}
      <p class="podcast-list__summary">{{ post.podcast_summary }}</p>
      {% endif %}
    </a>
    {% endfor %}
  </div>
  {% else %}
  <p>Ainda não há episódios publicados. Quando o pipeline semanal gerar os primeiros, eles aparecem aqui automaticamente.</p>
  {% endif %}
</div>
