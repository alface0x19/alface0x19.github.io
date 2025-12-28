---
layout: single
title: "Mapa do site"
permalink: /sitemap/
author_profile: false
sidebar: false
---

## Conteúdos recentes

<ul class="sitemap-list">
  {% for post in site.posts %}
  <li>
    <a href="{{ post.url | relative_url }}">{{ post.title }}</a>
    <span class="sitemap-list__meta">— {{ post.date | date: "%d %b %Y" }}</span>
  </li>
  {% endfor %}
</ul>

## Páginas

<ul class="sitemap-list">
  {% assign nav_pages = site.pages | where_exp: "page", "page.title" %}
  {% for page in nav_pages %}
    {% if page.url != "/feed.xml" and page.url != "/sitemap.xml" and page.title != "Mapa do site" %}
    <li><a href="{{ page.url | relative_url }}">{{ page.title }}</a></li>
    {% endif %}
  {% endfor %}
</ul>
