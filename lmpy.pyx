# -*- Mode: Python; tab-width: 8; indent-tabs-mode: nil; c-basic-offset: 8 -*-
cimport lmd
cimport python_exc
from python cimport PyObject, Py_INCREF, Py_DECREF
import traceback
import uuid

#OMG COPY_PASTE!!!
LM_MESSAGE_TYPE_MESSAGE = 0
LM_MESSAGE_TYPE_PRESENCE = 1
LM_MESSAGE_TYPE_IQ = 2
LM_MESSAGE_TYPE_STREAM = 3
LM_MESSAGE_TYPE_STREAM_ERROR = 4
LM_MESSAGE_TYPE_STREAM_FEATURES = 5
LM_MESSAGE_TYPE_AUTH = 6
LM_MESSAGE_TYPE_CHALLENGE = 7
LM_MESSAGE_TYPE_RESPONSE = 8
LM_MESSAGE_TYPE_SUCCESS = 9
LM_MESSAGE_TYPE_FAILURE = 10
LM_MESSAGE_TYPE_PROCEED = 11
LM_MESSAGE_TYPE_STARTTLS = 12
LM_MESSAGE_TYPE_UNKNOWN = 13

LM_MESSAGE_SUB_TYPE_NOT_SET = -10
LM_MESSAGE_SUB_TYPE_AVAILABLE = -1
LM_MESSAGE_SUB_TYPE_NORMAL = 0
LM_MESSAGE_SUB_TYPE_CHAT = 1
LM_MESSAGE_SUB_TYPE_GROUPCHAT = 2
LM_MESSAGE_SUB_TYPE_HEADLINE = 3
LM_MESSAGE_SUB_TYPE_UNAVAILABLE = 4
LM_MESSAGE_SUB_TYPE_PROBE = 5
LM_MESSAGE_SUB_TYPE_SUBSCRIBE = 6
LM_MESSAGE_SUB_TYPE_UNSUBSCRIBE = 7
LM_MESSAGE_SUB_TYPE_SUBSCRIBED = 8
LM_MESSAGE_SUB_TYPE_UNSUBSCRIBED = 9
LM_MESSAGE_SUB_TYPE_GET = 10
LM_MESSAGE_SUB_TYPE_SET = 11
LM_MESSAGE_SUB_TYPE_RESULT = 12
LM_MESSAGE_SUB_TYPE_ERROR = 13

LM_HANDLER_RESULT_REMOVE_MESSAGE = 0
LM_HANDLER_RESULT_ALLOW_MORE_HANDLERS = 1

LM_HANDLER_PRIORITY_LAST   = 1
LM_HANDLER_PRIORITY_NORMAL = 2
LM_HANDLER_PRIORITY_FIRST  = 3


cdef void result_fn(lmd.LmConnection* connection, lmd.gboolean success, lmd.gpointer user_data) with gil:
     cdef lmd.Callback* cb = <lmd.Callback*>user_data
     self = <object>cb.this
     cdef Connection conn = <Connection>self
     cdef char* method_name = cb.method_name
     lmd.free(user_data)

     cdef bool bool_status = False
     if success != 0:
         bool_status = True
     try:
         getattr(conn, method_name)(bool_status)
     except:
         print traceback.format_exc()

cdef lmd.GMainContext* g_main_context = lmd.g_main_context_new()
cdef lmd.GMainLoop* g_main_loop = lmd.g_main_loop_new(g_main_context, 0)


def start():
    with nogil:
        lmd.g_main_loop_run(g_main_loop)

def stop():
    lmd.g_main_loop_quit(g_main_loop)

def step():
    cdef lmd.gboolean result
    with nogil:
        result = lmd.g_main_context_iteration(g_main_context, 0)
    return bool(result)

cdef class MessageNode:
     cdef lmd.LmMessageNode* _node
     def __cinit__(self):
         self._node = NULL
     cdef _set(self, lmd.LmMessageNode* node):
         self._node = node
         return self

     def get_name(self):
         assert(self._node)
         return self._node.name
     def get_value(self):
         assert(self._node)
         return self._node.value if self._node.value != NULL else None

     def find_child(self, name = None):
         assert(self._node)
         ret = []
         cdef lmd.LmMessageNode* current_child = self._node.children
         while current_child != NULL:
             if current_child.name == name or name is None:
                 ret.append(MessageNode()._set(current_child))
             current_child = current_child.next
         return ret

     def add_child(self, char* name, char* value = ""):
         return MessageNode()._set(lmd.lm_message_node_add_child(self._node, name, value if len(value) > 0 else NULL))

     def set_attribute(self, char* name, char* value):
         lmd.lm_message_node_set_attribute(self._node, name, value)
         return self

     def get_child(self, char* name):
         cdef lmd.LmMessageNode* node = lmd.lm_message_node_get_child(self._node, name)
         if node == NULL:
             return None
         return MessageNode()._set(node)
     def __getitem__(self, char* name):
         cdef char* value = lmd.lm_message_node_get_attribute(self._node, name)
         if value == NULL:
             return None
             #raise KeyError(name)
         return value
     def __setitem__(self, char* name, char* value):
         self.set_attribute(name, value)

cdef class Message:
     cdef lmd.LmMessage* _message
     def __cinit__(self):
         self._message = NULL
     cdef _set(self, lmd.LmMessage* message):
         self._message = message
         return self

     def __init__(self, char* recipient, lmd.LmMessageType type, lmd.LmMessageSubType subtype = lmd.LM_MESSAGE_SUB_TYPE_NOT_SET, skip_construction = False):
         if not skip_construction:
             self._message = lmd.lm_message_new_with_sub_type(recipient if len(recipient) > 0 else NULL, type, subtype)
             if self._message == NULL:
                 raise RuntimeError("can't create message")
     def __dealloc__(self):
         if self._message != NULL:
             lmd.lm_message_unref(self._message)
     def get_node(self):
         return MessageNode()._set(lmd.lm_message_get_node(self._message))
     def find_child(self, *args, **kwargs):
         return self.get_node().find_child(*args, **kwargs)

cdef lmd.LmHandlerResult handler_fn(lmd.LmMessageHandler* c_handler,
                                    lmd.LmConnection* connection,
                                    lmd.LmMessage* message,
                                    lmd.gpointer user_data) with gil:
    self = <object>user_data
    cdef MessageHandler handler = <MessageHandler>self
    try:
        ret = handler.handle(Message("", 0, 0, skip_construction = True)._set(message))
        return ret if ret is not None else lmd.LM_HANDLER_RESULT_ALLOW_MORE_HANDLERS
    except:
        print traceback.format_exc()
        return lmd.LM_HANDLER_RESULT_ALLOW_MORE_HANDLERS

cdef class MessageHandler:
     cdef lmd.LmMessageHandler* _handler
     cdef lmd.LmMessageType _type
     cdef lmd.LmHandlerPriority _priority
     cdef object _callback

     def __cinit__(self):
         self._handler = NULL
     def __dealloc__(self):
         print "dealloc handler"
         if self._handler:
             lmd.lm_message_handler_unref(self._handler)
     def __init__(self, lmd.LmMessageType type, lmd.LmHandlerPriority priority, callback):
         cdef lmd.LmHandleMessageFunction cb = <lmd.LmHandleMessageFunction>&handler_fn
         self._handler = lmd.lm_message_handler_new(cb, <void*>self, NULL)
         if self._handler == NULL:
             raise RuntimeError("can't register handler")
         self._callback = callback
         self._type = type
         self._priority = priority
     def handle(self, message):
         ret = self._callback(message)
         return ret if ret is not None else lmd.LM_HANDLER_RESULT_ALLOW_MORE_HANDLERS

cdef class Connection:
     cdef lmd.LmConnection* _connection
     #cdef string jid
     #cdef string server
     #cdef string password
     #cdef int port

     def __cinit__(self):
         self._connection = NULL

     def _log(self, msg):
         #TODO: reimplement/override
         print msg

     def __dealloc__(self):
         print "dealloc"
         if self._connection:
             lmd.lm_connection_close(self._connection, NULL)
             self._connection = NULL

     def __init__(self, char* server, char* jid, int port, char* password):
         self._connection = lmd.lm_connection_new_with_context(server, g_main_context)
         if self._connection == NULL:
             raise RuntimeError("can't create connection")

         self.callbacks = {}
         self.handlers = []

         self.jid = jid
         self.port = port
         self.server = server
         self.password = password

         lmd.lm_connection_set_jid(self._connection, self.jid)
         lmd.lm_connection_set_port(self._connection, self.port)

     def get_jid(self):
         return self.jid

     def on_error(self, msg):
         #XXX useless
         self._log("error: " + msg)
         stop()

     def _on_connected(self, bool succeeded):
         cdef lmd.Callback* callback = <lmd.Callback*>lmd.malloc(sizeof(lmd.Callback))
         cdef char* username
         if succeeded:
             username_str = self.jid.split('@')[0]
             username = username_str
             callback.this = <void*>self
             callback.method_name = "on_authenticated"
             if lmd.lm_connection_authenticate(self._connection, username,
                                                self.password, "lm-send-async", <lmd.LmResultFunction>result_fn, <void*>callback, NULL, NULL) == 0:
                 raise RuntimeError("can't start authentication")
         else:
             self.on_error("connect")

     def on_authenticated(self, bool succeeded):
         if succeeded:
             self.register_handlers()
         self.on_connected(succeeded)

     def connect(self):
         cdef lmd.Callback* callback = <lmd.Callback*>lmd.malloc(sizeof(lmd.Callback))
         callback.this = <void*>self
         callback.method_name = "_on_connected"
         if lmd.lm_connection_open(self._connection, <lmd.LmResultFunction>result_fn, <void*>callback, NULL, NULL) == 0:
             raise RuntimeError("can't start connect")

     def close(self):
         print "close"
         if self._connection:
             lmd.lm_connection_close(self._connection, NULL)
             self._connection = NULL

     def register_handlers(self):
         self.handlers = [MessageHandler(x, LM_HANDLER_PRIORITY_NORMAL, self._on_event) for x in [LM_MESSAGE_TYPE_IQ, LM_MESSAGE_TYPE_PRESENCE, LM_MESSAGE_TYPE_MESSAGE]]
         [self.register_handler(x) for x in self.handlers]

     def on_message(self, message):
         raise NotImplementedError()

     def _on_event(self, message):
         ret = None
         try:
             uid = message.get_node()["id"]
             #print "EVENT: %s, %s, name: %s" % (str(uid), uid in self.callbacks, message.get_node().get_name())
             if uid not in self.callbacks:
                 ret = self.on_message(message)
             else:
                 try:
                     ret = self.callbacks[uid](message)
                 finally:
                     del self.callbacks[uid]
             return ret if ret is not None else lmd.LM_HANDLER_RESULT_REMOVE_MESSAGE
         except:
             print traceback.format_exc()
             return lmd.LM_HANDLER_RESULT_REMOVE_MESSAGE

     def send(self, Message msg, callback):
         uid = uuid.uuid4().get_hex()
         msg.get_node()["id"] = uid
         self.callbacks[uid] = callback
         self.send_message(msg)

     def send_message(self, Message msg):
         if lmd.lm_connection_send(self._connection, msg._message, NULL)  == 0:
             raise RuntimeError("can't send message")

     def send_raw(self, char* msg):
         if lmd.lm_connection_send_raw(self._connection, msg, NULL) == 0:
             raise RuntimeError("can't send data")

     def register_handler(self, MessageHandler handler):
         #XXX move register/unregister to MessageHandler ctor/dtor
         lmd.lm_connection_register_message_handler(self._connection,
                                                    handler._handler,
                                                    handler._type,
                                                    handler._priority
                                                    )
