---
layout: single
title: Podcast
permalink: /podcast/
author_profile: false
---

<div class="post">
  <h1>{{ page.title }}</h1>
  <p>Arquivo dos episódios publicados no site, com player embutido e links para o feed RSS do podcast.</p>
  <p><a href="{{ '/podcast.xml' | relative_url }}">Subscrever via RSS</a></p>

  {% assign has_podcast_posts = false %}
  {% for post in site.posts %}
    {% if post.audio_url and post.audio_url != '' %}
      {% assign has_podcast_posts = true %}
    {% endif %}
  {% endfor %}

  {% if has_podcast_posts %}
  <div class="podcast-list">
    {% for post in site.posts %}
      {% if post.audio_url and post.audio_url != '' %}
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
      {% endif %}
    {% endfor %}
  </div>
  {% else %}
  <p>Ainda não há episódios publicados. Quando o pipeline semanal gerar os primeiros, eles aparecem aqui automaticamente.</p>
  {% endif %}
</div>
