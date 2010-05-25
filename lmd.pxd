# -*- Mode: text; tab-width: 8; indent-tabs-mode: nil; c-basic-offset: 8 -*-

cdef extern from "stdlib.h":
     void* malloc(long size)
     void free(void* data)
     

cdef extern from "glib.h":
     ctypedef char gchar
     ctypedef int  gint
     ctypedef void* gpointer
     ctypedef unsigned int  guint
     ctypedef gint gboolean

     ctypedef void (*GDestroyNotify) (gpointer data)
     ctypedef struct GError:
              pass
     ctypedef struct GMainContext:
              pass
     GMainContext *      g_main_context_new()
     ctypedef struct GMainLoop:
              pass
     GMainLoop * g_main_loop_new              (GMainContext *context,
                                               gboolean is_running)
     void     g_main_loop_run                 (GMainLoop *loop) nogil

     void     g_main_loop_quit                (GMainLoop *loop)
     gboolean g_main_context_iteration        (GMainContext *context, gboolean may_block) nogil


ctypedef struct Callback:
     void* this
     char* method_name


ctypedef enum LmMessageType:
        LM_MESSAGE_TYPE_MESSAGE = 0,
        LM_MESSAGE_TYPE_PRESENCE,
        LM_MESSAGE_TYPE_IQ,
        LM_MESSAGE_TYPE_STREAM,
        LM_MESSAGE_TYPE_STREAM_ERROR,
        LM_MESSAGE_TYPE_STREAM_FEATURES,
        LM_MESSAGE_TYPE_AUTH,
        LM_MESSAGE_TYPE_CHALLENGE,
        LM_MESSAGE_TYPE_RESPONSE,
        LM_MESSAGE_TYPE_SUCCESS,
        LM_MESSAGE_TYPE_FAILURE,
        LM_MESSAGE_TYPE_PROCEED,
        LM_MESSAGE_TYPE_STARTTLS,
        LM_MESSAGE_TYPE_UNKNOWN

ctypedef enum LmMessageSubType:
        LM_MESSAGE_SUB_TYPE_NOT_SET = -10,
        LM_MESSAGE_SUB_TYPE_AVAILABLE = -1,
        LM_MESSAGE_SUB_TYPE_NORMAL = 0,
        LM_MESSAGE_SUB_TYPE_CHAT,
        LM_MESSAGE_SUB_TYPE_GROUPCHAT,
        LM_MESSAGE_SUB_TYPE_HEADLINE,
        LM_MESSAGE_SUB_TYPE_UNAVAILABLE,
        LM_MESSAGE_SUB_TYPE_PROBE,
        LM_MESSAGE_SUB_TYPE_SUBSCRIBE,
        LM_MESSAGE_SUB_TYPE_UNSUBSCRIBE,
        LM_MESSAGE_SUB_TYPE_SUBSCRIBED,
        LM_MESSAGE_SUB_TYPE_UNSUBSCRIBED,
        LM_MESSAGE_SUB_TYPE_GET,
        LM_MESSAGE_SUB_TYPE_SET,
        LM_MESSAGE_SUB_TYPE_RESULT,
        LM_MESSAGE_SUB_TYPE_ERROR

ctypedef enum LmHandlerResult:
        LM_HANDLER_RESULT_REMOVE_MESSAGE,
        LM_HANDLER_RESULT_ALLOW_MORE_HANDLERS

ctypedef enum LmHandlerPriority:
        LM_HANDLER_PRIORITY_LAST   = 1,
        LM_HANDLER_PRIORITY_NORMAL = 2,
        LM_HANDLER_PRIORITY_FIRST  = 3


cdef extern from "loudmouth/loudmouth.h":
     ctypedef struct LmConnection:
          pass
     ctypedef struct LmMessageNode:
          char* name
          char* value
          gboolean raw_mode

          LmMessageNode* next
          LmMessageNode* prev
          LmMessageNode* parent
          LmMessageNode* children
          
          void* attributes
          gint ref_count

     ctypedef struct LmMessageHandler:
          pass
     ctypedef struct LmMessage:
          LmMessageNode* node
          LmMessageNode* priv


     ctypedef void (*LmResultFunction)     (LmConnection       *connection,
                                                gboolean            success,
                                                gpointer            user_data)

     ctypedef LmHandlerResult (*LmHandleMessageFunction) (LmMessageHandler *handler,
                                                     LmConnection     *connection,
                                                     LmMessage        *message,
                                                     gpointer          user_data)

     LmConnection *lm_connection_new (char* server)
     LmConnection *lm_connection_new_with_context (char *server,
                                                   GMainContext *context)

     gboolean      lm_connection_close (LmConnection       *connection,
                                               GError            **error)          
     void          lm_connection_set_jid (LmConnection       *connection,
                                               char        *jid)
     char *       lm_connection_get_jid  (LmConnection *connection)
     void          lm_connection_set_port (LmConnection       *connection,
                                               guint               port)

     gboolean      lm_connection_open     (LmConnection       *connection,
                                               LmResultFunction    function,
                                               gpointer            user_data,
                                               GDestroyNotify      notify,
                                               GError            **error)

     gboolean      lm_connection_authenticate      (LmConnection       *connection,
                                               char        *username,
                                               char        *password,
                                               char        *resource,
                                               LmResultFunction    function,
                                               gpointer            user_data,
                                               GDestroyNotify      notify,
                                               GError            **error)

     gboolean      lm_connection_send              (LmConnection       *connection,
                                               LmMessage          *message,
                                               GError            **error)

     gboolean      lm_connection_send_raw          (LmConnection       *connection,
                                               char        *str,
                                               GError            **error)

     LmMessage *      lm_message_new          (char      *to,
                                               LmMessageType     type)

     LmMessage *      lm_message_new_with_sub_type (char      *to,
                                               LmMessageType     type,
                                               LmMessageSubType  sub_type)

     void             lm_message_unref        (LmMessage        *message)
     LmMessageNode *  lm_message_get_node          (LmMessage        *message)
     char *  lm_message_node_get_value      (LmMessageNode *node)

     LmMessageNode * lm_message_node_add_child      (LmMessageNode *node,
                                               char   *name,
                                               char   *value)
     LmMessageNode *lm_message_node_get_child      (LmMessageNode *node,
					       char   *child_name)
     void           lm_message_node_set_attribute  (LmMessageNode *node,
					       char   *name,
					       char   *value)
     char *  lm_message_node_get_attribute  (LmMessageNode *node,
					       char   *name)
     LmMessageHandler *lm_message_handler_new   (LmHandleMessageFunction  function,
                                            gpointer                 user_data,
                                            GDestroyNotify           notify)
     void              lm_message_handler_unref (LmMessageHandler        *handler)

     void lm_connection_register_message_handler        (LmConnection       *connection,
                                               LmMessageHandler   *handler,
                                               LmMessageType       type,
                                               LmHandlerPriority   priority)
     void lm_connection_unregister_message_handler      (LmConnection       *connection,
                                               LmMessageHandler   *handler,
                                               LmMessageType       type)
