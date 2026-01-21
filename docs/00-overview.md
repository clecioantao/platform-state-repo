# Visão Geral

## Problema
Times de desenvolvimento precisam criar aplicações rapidamente,
mas a criação de infraestrutura isolada gera:
- inconsistência
- falta de governança
- dificuldade de evolução para produção

## Objetivo da PoC
Demonstrar uma plataforma onde:
- a **aplicação** é a unidade central
- infraestrutura nasce vinculada a **app + ambiente**
- desenvolvedores usam **self-service**, não kubectl
- operadores mantêm controle e padrões

## Princípios
- Nada fora de Git
- Nada aplicado manualmente (exceto bootstrap)
- Nada de infra sem app
