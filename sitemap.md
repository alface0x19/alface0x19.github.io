---
layout: single
title: "Mapa do site"
permalink: /sitemap/
author_profile: false
sidebar: false
---

## Conteúdos recentes

<ul class="sitemap-grid">
  {% for post in site.posts %}
  <li class="sitemap-card">
    <div class="sitemap-card__meta">{{ post.date | date: "%d %b %Y" }}</div>
    <a class="sitemap-card__title" href="{{ post.url | relative_url }}">{{ post.title }}</a>
    <p class="sitemap-card__excerpt">{{ post.excerpt | strip_html | truncate: 160 }}</p>
  </li>
  {% endfor %}
</ul>

## Páginas

<ul class="sitemap-pages">
  {% assign nav_pages = site.pages | where_exp: "page", "page.title" %}
  {% for page in nav_pages %}
    {% if page.url != "/feed.xml" and page.url != "/sitemap.xml" and page.title != "Mapa do site" %}
    <li><a href="{{ page.url | relative_url }}">{{ page.title }}</a></li>
    {% endif %}
  {% endfor %}
</ul>
