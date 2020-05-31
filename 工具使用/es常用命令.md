# ES常用命令

## 1.创建索引

```http
PUT /huangfu
{
  "settings": {
    "number_of_replicas": 0 
    , "number_of_shards": 1
  }
}
```

### 1.1 参数解析

- number_of_replicas 副本数
- number_of_shards 分片数

## 2.修改索引的副本数

```http
PUT huangfu/_settings
{
  "number_of_replicas" : "2"
}
```

## 3. 删除索引

```http
DELETE /huangfu
```

## 4. 插入数据

### 4.1 手动指定id

```http
POST /huangfu/_doc/1001
{
  "id" : 1001,
  "name" : "皇甫科星",
  "age" : 25,
  "sex" : "男"
}
```

### 4.2 不指定id 系统自动生成

```http
POST /huangfu/_doc/
{
  "id" : 1002,
  "name" : "小皇子",
  "age" : 28,
  "sex" : "男"
}
```

### 4.3 参数解析

- POST：插入数据
- huangfu：索引名称
- _doc： 类型
- 1001：id

## 5.更新数据

```http
PUT /huangfu/_doc/1001
{
  "id":1009,
  "name" : "皇甫",
  "age" : 26,
  "sex" : "女"
}
```

## 6. 局部更新数据

```http
POST /huangfu/_update/1001
{
  "doc":{
    "age" : 23
  }
}
```

## 7. 查询数据

```http
GET /huangfu/_doc/1001
```

### 7.1. 搜索全部数据

```http
GET /huangfu/_search
```

​	`注意：默认最多返回十条数据`

```json
{
  "took" : 0,
  "timed_out" : false,
  "_shards" : {
    "total" : 1,
    "successful" : 1,
    "skipped" : 0,
    "failed" : 0
  },
  "hits" : {
    "total" : {
      "value" : 2,
      "relation" : "eq"
    },
    "max_score" : 1.0,
    "hits" : [
      {
        "_index" : "huangfu",
        "_type" : "_doc",
        "_id" : "yT8JanIBX1WF9aA1RN88",
        "_score" : 1.0,
        "_source" : {
          "id" : 1002,
          "name" : "小皇子",
          "age" : 28,
          "sex" : "男"
        }
      },
      {
        "_index" : "huangfu",
        "_type" : "_doc",
        "_id" : "1001",
        "_score" : 1.0,
        "_source" : {
          "id" : 1009,
          "name" : "皇甫",
          "age" : 23,
          "sex" : "女"
        }
      }
    ]
  }
}
```

### 7.2 DSL搜索

> 查询 年龄是23的数据

```http
POST /huangfu/_search
{
  "query": {
    "match": {
      "age": 23
    }
  }
}
```

> 查询姓名是小皇子的数据

```http
POST /huangfu/_search
{
  "query": {
    "match_phrase": {
      "name": "小皇子"
    }
  }
}
```

- **注意**：match 中如果加空格，那么会被认为两个单词，包含任意一个单词将被查询到 
- **注意**：match_parase 将忽略空格，将该字符认为一个整体，会在索引中匹配包含这个整体的文档。

> 查询年龄大于23的并且是男性

```http
POST /huangfu/_search
{
  "query": {
    "bool": {
      "filter": {
        "range": {
          "age": {
            "gt": 23
          }
        }
      },
      "must": [
        {
          "match": {
            "sex": "男"
          }
        }
      ]
    }
  }
}
```

> 高亮显示

```http
POST /huangfu/_search
{
  "query": {
    "match_phrase": {
      "name": "皇甫"
    }
  },
  "highlight": {
    "fields": {
      "name" : {}
    }
  }
}
```

> 聚合查询

```http
POST /huangfu/_search
{
  "aggs": {
    "all_interests": {
      "terms": {
        "field": "age"
      }
    }
  }
}
```

- 类似与 mysql的group by操作

> 去掉元数据

```http
GET /huangfu/_source/1001
```

```json
{
  "id" : 1009,
  "name" : "皇甫",
  "age" : 23,
  "sex" : "女"
}

```

> 去掉元数据返回指定字段

```http
GET /huangfu/_source/1001?_source=name,age
```

```json
{
  "name" : "皇甫",
  "age" : 23
}

```

> 判断文档是否存在

```http
HEAD /huangfu/_doc/1001
```

>返回结果类似下面的信息
```http
404 - Not Found
200 - OK
```

> 批量查询

```http
POST /huangfu/_mget
{
  "ids" : ["1001","yT8JanIBX1WF9aA1RN88"]
}
```

> 批量插入

```http

```



### 7.x 结果参数解析

- took Elasticsearch运行查询需要多长时间(以毫秒为单位) 

- timed_out 搜索请求是否超时 

- _shards 搜索了多少碎片，并对多少碎片成功、失败或跳过进行了细分。 

- max_score 找到最相关的文档的得分

- hits.total.value 找到了多少匹配的文档 

- hits.sort 文档的排序位置(当不根据相关性得分排序时)

- hits._score 文档的相关性评分(在使用match_all时不适用)

### 7.x 参数解析

- GET：方法
- huangfu：索引名
- _doc：数据类型
- 1001：id