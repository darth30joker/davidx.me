Title: 如何给nova写API和CLI
Slug: how-to-write-apis-and-cli-for-nova
Date: 2014-04-02 14:51
Category: OpenStack
Tags: OpenStack, Nova
Author: David Xie
Summary: 如何给nova写API和CLI

很多时候, 大家可能觉得Nova提供的API不能满足自己的需求, 那么就需要自己写一套API出来. 写出来API后, 如果希望能更方便的使用的话, 那么还需要写一套CLI出来调用刚刚写的API, 这样, 一个完整的命令就创建出来了.

所以我们首先要从创建API开始.

Nova的API, 默认都在nova.api.openstack.compute.contrib里, 所以你写的API, 一定要安装到这个路径下才可以. 一个完整的API, 需要以下几个要素:

1. controller
2. extension

Controller是一个普通的object就可以了, extension必须继承extensions.ExtensionDescriptor, 并且重写get_resources方法. 这里给出一个最简单的例子来:

    from webob import exc

    from oslo import messaging

    from nova import compute
    from nova.ibm.ego import ego_gettextutils
    from nova.ibm.ego import hapolicy

    from nova.api.openstack import extensions
    from nova.api.openstack import wsgi
    from nova.api.openstack import xmlutil

    from nova.openstack.common import log as logging

    LOG = logging.getLogger(__name__)

    _ = ego_gettextutils._


    ALIAS = "ibm-ha-policy"


    def authorize(context, action_name):
        action = '%s:%s' % (ALIAS, action_name)
        extensions.extension_authorizer('compute', action)(context)


    class HAPolicyTemplate(xmlutil.TemplateBuilder):
        def construct(self):
            """
            Construct a single HA policy
            """
            version = 1
            root = xmlutil.TemplateElement('hapolicy',
                                           selector='hapolicy')
            make_policy(root)
            return xmlutil.MasterTemplate(root, version)


    class HAPolicyController(object):
        """
        The HA Policy API controller for the OpenStack API.
        """

        def __init__(self):
            self.compute_api = compute.API()
            self.hapolicy_api = hapolicy.API()
            super(HAPolicyController, self).__init__()

        @wsgi.serializers(xml=HAPoliciesTemplate)
        def index(self, req):
            """
            :param req: GET /v2/{tenant_id}/ego/policy/ha

            Return a list of HA policies allocated to a project.
            """
            context = req.environ['nova.context']
            authorize(context, 'index')
            policies = self.hapolicy_api.get_all(context)
            return {'policies': policies}

        @wsgi.serializers(xml=HAPolicyTemplate)
        def show(self, req, id):
            """
            :param req: GET /v2/{tenant_id}/ego/policy/ha/{id}
            :param id: HA policy id

            Return details of a specified policy
            """
            context = req.environ['nova.context']
            authorize(context, 'show')
            try:
                policy = self.hapolicy_api.get(context, id)
            except messaging.RemoteError as e:
                if e.exc_type == 'HAPolicyNotFound':
                    msg = _("The system cannot get policy %(id)s due to "
                            "%(reason)s") % {'id': id, 'reason': e.value}
                    raise exc.HTTPNotFound(explanation=msg)
            except Exception as e:
                LOG.info(unicode(e))
                raise
            return {'policy': policy}

        @wsgi.serializers(xml=HAPolicyTemplate)
        def update(self, req, id, body):
            """
            :param req: GET /v2/{tenant_id}/ego/policy/ha/{id}
            :param id: policy id
            :param body: {policy':
                            {'description': 'example',
                             'xxx': 'xxx'
                            }
                         }
            Update one specified HA policy and return details
            of the specified policy
            """
            context = req.environ['nova.context']
            authorize(context, 'update')
            try:
                policy = body['policy']
            except KeyError:
                msg = _("Policy update body should be policy")
                raise exc.HTTPBadRequest(explanation=msg)

            try:
                updated_policy = self.hapolicy_api.update(context,
                                                          id,
                                                          policy)
            except messaging.RemoteError as e:
                if e.exc_type == 'HAPolicyNotFound':
                    raise exc.HTTPNotFound(explanation=e.value)
                elif e.exc_type in ['InvalidHAPolicyAction',
                                    'InvalidHAPolicyState',
                                    'InvalidHAPolicyInput',
                                    'HAPolicyEGOConnLost']:
                    raise exc.HTTPBadRequest(explanation=e.value)
            except Exception as e:
                LOG.info(unicode(e))
                raise
            return {'policy': policy}


    class Hapolicy(extensions.ExtensionDescriptor):
        """Resource Optimization Policy."""

        name = "IBM HA Policy"
        alias = ALIAS
        namespace = ("http://ibm.com/compute/ext/ego/policy/ha/api/v2.0")
        updated = "2013-02-24T00:00:00+00:00"

        def get_resources(self):
            """Returns a list of policy objects."""
            resources = []

            res = extensions.ResourceExtension('ego/policy/ha',
                                               HAPolicyController(),
                                               member_actions={})
            resources.append(res)

            return resources
