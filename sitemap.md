---
layout: single
title: "Mapa do site"
permalink: /sitemap/
author_profile: false
sidebar: false
---

## Conteúdos recentes

<div class="sitemap-search">
  <label for="sitemap-filter">Pesquisar conteúdos</label>
  <input id="sitemap-filter" type="search" placeholder="Filtrar por título" aria-describedby="sitemap-filter-help">
  <small id="sitemap-filter-help">Mostra posts e páginas correspondentes ao texto pesquisado.</small>
</div>

<ul class="sitemap-list">
  {% for post in site.posts %}
  <li>
    <a href="{{ post.url | relative_url }}">{{ post.title }}</a>
    <span class="sitemap-list__meta">— {{ post.date | date: "%d %b %Y" }}</span>
  </li>
  {% endfor %}
</ul>

<script>
document.addEventListener('DOMContentLoaded', function () {
  var filterInput = document.getElementById('sitemap-filter');
  if (!filterInput) {
    return;
  }

  var lists = document.querySelectorAll('.sitemap-list');

  filterInput.addEventListener('input', function () {
    var query = filterInput.value.trim().toLowerCase();

    lists.forEach(function (list) {
      list.querySelectorAll('li').forEach(function (item) {
        var text = item.textContent.toLowerCase();
        item.style.display = query && text.indexOf(query) === -1 ? 'none' : '';
      });
    });
  });
});
</script>

## Páginas

<ul class="sitemap-list">
  {% assign nav_pages = site.pages | where_exp: "page", "page.title" %}
  {% for page in nav_pages %}
    {% if page.url != "/feed.xml" and page.url != "/sitemap.xml" and page.title != "Mapa do site" %}
    <li><a href="{{ page.url | relative_url }}">{{ page.title }}</a></li>
    {% endif %}
  {% endfor %}
</ul>
