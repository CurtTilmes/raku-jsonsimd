#include "simdjson.h"

extern "C" { namespace simdjson {

extern SIMDJSON_DLLIMPORTEXPORT
const char *simdjson_errstr(int code)
{
    return internal::error_codes[code].message.c_str();
}

extern SIMDJSON_DLLIMPORTEXPORT
dom::parser *parser_new()
{
    dom::parser *parser = new dom::parser;
    return parser;
}

extern SIMDJSON_DLLIMPORTEXPORT
dom::parser *parser_new_size(size_t size)
{
    dom::parser *parser = new dom::parser(size);
    return parser;
}

extern SIMDJSON_DLLIMPORTEXPORT
int parser_allocate(dom::parser *parser, size_t size, size_t max_depth, int *err)
{
    error_code error = parser->allocate(size, max_depth);
    return *err = (int) error;
}

extern SIMDJSON_DLLIMPORTEXPORT
size_t parser_capacity(dom::parser *parser)
{
    return parser->capacity();
}

extern SIMDJSON_DLLIMPORTEXPORT
dom::element *parser_load(dom::parser *parser, const char *path, int *err)
{
    dom::element *element = new dom::element();
    error_code error;
    parser->load(path).tie(*element, error);
    if (error) { *err = (int) error; return (dom::element *) NULL; }
    return element;
}

extern SIMDJSON_DLLIMPORTEXPORT
dom::element *parser_parse(dom::parser *parser, const char *str, size_t length,
                           int *err)
{
    dom::element *element = new dom::element();
    error_code error;
    parser->parse(padded_string(str, length)).tie(*element, error);
    if (error) { *err = (int) error; return (dom::element *) NULL; }
    return element;
}

extern SIMDJSON_DLLIMPORTEXPORT
void parser_parsemany(dom::parser *parser, const uint8_t *buf, size_t len,
                      void *userdata,
                      void (*callback)(void *, dom::element *, int))
{
    for (auto [doc, error] : parser->parse_many(buf,len))
    {
        if (error)
        {
            (*callback)(userdata, (dom::element *) NULL, (int) error);
            return;
        }
        (*callback)(userdata, &doc, 0);
    }
    (*callback)(userdata, (dom::element *) NULL, 0);
}

extern SIMDJSON_DLLIMPORTEXPORT
void parser_loadmany(dom::parser *parser, const char *path, void *userdata,
                     void (*callback)(void *, dom::element *, int))
{
    for (auto [doc, error] : parser->load_many(path))
    {
        if (error)
        {
            (*callback)(userdata, (dom::element *) NULL, (int) error);
            return;
        }
        (*callback)(userdata, &doc, 0);
    }
    (*callback)(userdata, (dom::element *) NULL, 0);
}

extern SIMDJSON_DLLIMPORTEXPORT
void parser_free(dom::parser *parser)
{
    delete parser;
}

extern SIMDJSON_DLLIMPORTEXPORT
const char *implementation_name()
{
    return active_implementation->name().data();
}

extern SIMDJSON_DLLIMPORTEXPORT
const char *implementation_description()
{
    return active_implementation->description().data();
}

extern SIMDJSON_DLLIMPORTEXPORT
int element_type(dom::element *element)
{
    return static_cast<int>(element->type());
}

union element_union
{
    dom::element *e;
    const char *s;
    int64_t i;
    uint64_t u;
    double d;
    bool b;
};

void store_element(dom::element *src, element_union *dest)
{
    error_code error;

    switch (src->type())
    {
        case dom::element_type::OBJECT :
            dest->e = new dom::element(*src);
            break;
        case dom::element_type::ARRAY :
            dest->e = new dom::element(*src);
            break;
        case dom::element_type::DOUBLE :
            src->get<double>().tie(dest->d, error);
            break;
        case dom::element_type::STRING :
            src->get<const char *>().tie(dest->s, error);
            break;
        case dom::element_type::INT64 :
            src->get<int64_t>().tie(dest->i, error);
            break;
        case dom::element_type::UINT64 :
            src->get<uint64_t>().tie(dest->u, error);
            break;
        case dom::element_type::BOOL :
            src->get<bool>().tie(dest->b, error);
            break;
        default :
            break;
    }
}

typedef struct _arraycontent
{
    int type;
    element_union elem;
} arraycontent;

extern SIMDJSON_DLLIMPORTEXPORT
arraycontent *element_array(dom::element *element)
{
    dom::array array;
    error_code error;
    element->get<dom::array>().tie(array, error);
    if (error) return (arraycontent *) NULL;

    int count = array.size();
    arraycontent *arr = new arraycontent[count+1];
    if (!arr) return arr;
    arr->elem.i = count;       // Slot 0 has count of remaining elements
    arraycontent *p = arr + 1; // Rest of content start in slot 1
    for (dom::element child : dom::array(*element))
    {
        p->type = (int) child.type();
        store_element(&child, &(p->elem));
        p++;
    }
    return arr;
}

extern SIMDJSON_DLLIMPORTEXPORT
void arraycontent_free(arraycontent *arr)
{
    delete arr;
}

typedef struct _objectcontent
{
    int type;
    const char *key;
    element_union elem;
} objectcontent;

extern SIMDJSON_DLLIMPORTEXPORT
objectcontent *element_object(dom::element *element)
{
    dom::object object;
    error_code error;
    element->get<dom::object>().tie(object, error);
    if (error) return (objectcontent *) NULL;

    int count = object.size();
    objectcontent *arr = new objectcontent[count+1];
    if (!arr) return arr;
    arr->elem.i = count;         // Slot 0 has count of remaining elements
    objectcontent *p = arr + 1;  // Rest of content start in slot 1
    for (dom::key_value_pair field : object)
    {
        p->key = field.key.data();
        p->type = (int) field.value.type();
        store_element(&(field.value), &(p->elem));
        p++;
    }
    return arr;
}

extern SIMDJSON_DLLIMPORTEXPORT
void objectcontent_free(objectcontent *arr)
{
    delete arr;
}

extern SIMDJSON_DLLIMPORTEXPORT
const char *element_string(dom::element *element)
{
    const char *str;
    error_code error;
    element->get<const char *>().tie(str, error);
    if (error) return (const char *) NULL;
    return str;
}

extern SIMDJSON_DLLIMPORTEXPORT
int64_t element_int(dom::element *element)
{
    int64_t i;
    error_code error;
    element->get<int64_t>().tie(i, error);
    return i;
}

extern SIMDJSON_DLLIMPORTEXPORT
uint64_t element_uint(dom::element *element)
{
    uint64_t i;
    error_code error;
    element->get<uint64_t>().tie(i, error);
    return i;
}

extern SIMDJSON_DLLIMPORTEXPORT
double element_double(dom::element *element)
{
    double d;
    error_code error;
    element->get<double>().tie(d, error);
    return d;
}

extern SIMDJSON_DLLIMPORTEXPORT
bool element_bool(dom::element *element)
{
    bool b;
    error_code error;
    element->get<bool>().tie(b, error);
    return b;
}

extern SIMDJSON_DLLIMPORTEXPORT
dom::element *element_at_key(dom::element *obj, const char *key)
{
    dom::element *element = new dom::element();
    error_code error;
    obj->at(key).tie(*element, error);
    if (error) return (dom::element *) NULL;
    return element;
}

extern SIMDJSON_DLLIMPORTEXPORT
size_t element_size(dom::element *element)
{
    if (element->type() == dom::element_type::OBJECT)
    {
        return element->get<dom::object>().size();
    }
    else if (element->type() == dom::element_type::ARRAY)
    {
        return element->get<dom::array>().size();
    }
    return 0;
}

extern SIMDJSON_DLLIMPORTEXPORT
dom::element *element_at(dom::element *obj, size_t index)
{
    dom::element *element = new dom::element();
    error_code error;
    obj->at(index).tie(*element, error);
    if (error) return (dom::element *) NULL;
    return element;
}

} // namespace simdjson
} // extern C
