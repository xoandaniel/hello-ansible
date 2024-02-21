#!/usr/bin/env python
from ansible.module_utils.basic import AnsibleModule
import os
def main():
    module = AnsibleModule(argument_spec={}, supports_check_mode=True)
    result = dict(changed=False)
    load_1, load_5, load_15 = os.getloadavg()
    result['load_1'] = load_1
    result['load_5'] = load_5
    result['load_15'] = load_15
    module.exit_json(**result)
if __name__ == '__main__':
    main()
