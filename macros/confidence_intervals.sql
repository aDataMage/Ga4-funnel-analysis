{#
  Confidence intervals for proportions, computed in SQL so BI tools that cannot
  do this themselves (Excel, Tableau) plot intervals that match statsmodels.
  Pass n through nullif(n, 0) where it can be zero: the formula divides by n.

  Both match statsmodels exactly:
    wilson_bound    -> proportion_confint(k, n, method='wilson')
    newcombe_bound  -> confint_proportions_2indep(k1, n1, k2, n2,
                         compare='diff', method='newcomb')
  z defaults to the two-sided 95% critical value statsmodels uses.
#}

{% macro wilson_bound(k, n, side='lower', z=1.959964) -%}
    safe_divide(
        safe_divide({{ k }}, {{ n }})
            + pow({{ z }}, 2) / (2 * {{ n }})
            {{ '-' if side == 'lower' else '+' }} {{ z }} * sqrt(
                safe_divide({{ k }}, {{ n }}) * (1 - safe_divide({{ k }}, {{ n }})) / {{ n }}
                + pow({{ z }}, 2) / (4 * pow({{ n }}, 2))
            ),
        1 + pow({{ z }}, 2) / {{ n }}
    )
{%- endmacro %}


{# Newcombe's hybrid score interval for p1 - p2, built from the two Wilson intervals. #}
{% macro newcombe_bound(k1, n1, k2, n2, side='lower') -%}
    {%- set p1 = 'safe_divide(' ~ k1 ~ ', ' ~ n1 ~ ')' -%}
    {%- set p2 = 'safe_divide(' ~ k2 ~ ', ' ~ n2 ~ ')' -%}
    {%- if side == 'lower' -%}
    ({{ p1 }} - {{ p2 }}) - sqrt(
        pow({{ p1 }} - {{ wilson_bound(k1, n1, 'lower') }}, 2)
        + pow({{ wilson_bound(k2, n2, 'upper') }} - {{ p2 }}, 2)
    )
    {%- else -%}
    ({{ p1 }} - {{ p2 }}) + sqrt(
        pow({{ wilson_bound(k1, n1, 'upper') }} - {{ p1 }}, 2)
        + pow({{ p2 }} - {{ wilson_bound(k2, n2, 'lower') }}, 2)
    )
    {%- endif -%}
{%- endmacro %}
