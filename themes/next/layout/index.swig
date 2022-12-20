{% extends '_layout.swig' %}
{% import '_macro/sidebar.swig' as sidebar_template with context %}
<meta name="baidu-site-verification" content="code-v7Cv9HHNan" />
{% block title %}{{ theme.keywords }} - {{ title }}{{ theme.description }}{%- if theme.index_with_subtitle and subtitle %} - {{ subtitle }}{%- endif %}{% endblock %}

{% block class %}index posts-expand{% endblock %}

{% block content %}

  {%- for post in page.posts.toArray() %}
    {{ partial('_macro/post.swig', {post: post, is_index: true}) }}
  {%- endfor %}

  {% include '_partials/pagination.swig' %}

{% endblock %}

{% block sidebar %}
  {{ sidebar_template.render(false) }}
{% endblock %}
