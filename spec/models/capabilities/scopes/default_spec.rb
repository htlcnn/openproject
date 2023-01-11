#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2023 the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

require 'spec_helper'

describe Capabilities::Scopes::Default do
  # we focus on the non current user capabilities to make the tests easier to understand
  subject(:scope) { Capability.default.where(principal_id: user.id) }

  shared_let(:project) { create(:project) }
  shared_let(:user) { create(:user) }

  let(:permissions) { %i[] }
  let(:global_permissions) { %i[] }
  let(:non_member_permissions) { %i[] }
  let(:anonymous_permissions) { %i[] }
  let(:role) do
    create(:role, permissions:)
  end
  let(:global_role) do
    create(:global_role, permissions: global_permissions)
  end
  let(:global_member) do
    create(:global_member,
           principal: user,
           roles: [global_role])
  end
  let(:member) do
    create(:member,
           principal: user,
           roles: [role],
           project:)
  end
  let(:non_member_role) do
    create(:non_member,
           permissions: non_member_permissions)
  end
  let(:anonymous_role) do
    create(:anonymous_role,
           permissions: anonymous_permissions)
  end
  let(:own_role) { create(:role, permissions: []) }
  let(:own_member) do
    create(:member,
           principal: current_user,
           roles: [own_role],
           project:)
  end
  let(:members) { [] }

  shared_current_user do
    create(:admin)
  end

  shared_examples_for 'consists of contract actions' do
    it 'includes the expected for the scoped to user' do
      expect(scope.pluck(:action, :principal_id, :context_id))
        .to match_array(expected)
    end
  end

  shared_examples_for 'is empty' do
    it 'is empty for the scoped to user' do
      expect(scope)
        .to be_empty
    end
  end

  describe '.default' do
    before do
      members
    end

    context 'without any members and non member roles' do
      it_behaves_like 'is empty'
    end

    context 'with a member without a permission' do
      let(:members) { [member] }

      it_behaves_like 'is empty'
    end

    context 'with a global member without a permission' do
      let(:members) { [global_member] }

      it_behaves_like 'is empty'
    end

    context 'with a non member role without a permission' do
      let(:members) { [non_member_role] }

      it_behaves_like 'is empty'
    end

    context 'with a global member with an action permission' do
      let(:global_permissions) { %i[manage_user] }
      let(:members) { [global_member] }

      it_behaves_like 'consists of contract actions' do
        let(:expected) do
          [['users/create', user.id, nil],
           ['users/read', user.id, nil],
           ['users/update', user.id, nil]]
        end
      end
    end

    context 'with a member with an action permission' do
      let(:permissions) { %i[manage_members] }
      let(:members) { [member] }

      it_behaves_like 'consists of contract actions' do
        let(:expected) do
          [['memberships/create', user.id, project.id],
           ['memberships/destroy', user.id, project.id],
           ['memberships/update', user.id, project.id]]
        end
      end
    end

    context 'with a global member with an action permission and the user being locked' do
      let(:permissions) { %i[manage_user] }
      let(:members) { [global_member] }

      before do
        user.locked!
      end

      it_behaves_like 'is empty'
    end

    context 'with a member with an action permission and the user being locked' do
      let(:permissions) { %i[manage_members] }
      let(:members) { [member] }

      before do
        user.locked!
      end

      it_behaves_like 'is empty'
    end

    context 'with the non member role with an action permission' do
      let(:non_member_permissions) { %i[view_members] }
      let(:members) { [non_member_role] }

      context 'with the project being private' do
        it_behaves_like 'is empty'
      end

      context 'with the project being public' do
        before do
          project.update(public: true)
        end

        it_behaves_like 'consists of contract actions' do
          let(:expected) do
            [
              ['memberships/read', user.id, project.id]
            ]
          end
        end
      end
    end

    context 'with the anonymous role having the action permission in a public project' do
      let(:anonymous_permissions) { %i[view_members] }
      let(:members) { [anonymous_role] }

      before do
        project.update(public: true)
      end

      it_behaves_like 'is empty'
    end

    context 'with the anonymous user with an action permission' do
      let(:anonymous_permissions) { %i[view_members] }
      let!(:user) { create(:anonymous) }
      let(:members) { [anonymous_role] }

      context 'with the project being private' do
        it_behaves_like 'is empty'
      end

      context 'with the anonymous role not having the permission' do
        let(:anonymous_permissions) { %i[] }

        it_behaves_like 'is empty'
      end

      context 'with the project being public' do
        before do
          project.update(public: true)
        end

        it_behaves_like 'consists of contract actions' do
          let(:expected) do
            [
              ['memberships/read', user.id, project.id]
            ]
          end
        end
      end
    end

    context 'with a member without a permission and with the non member having a permission' do
      let(:non_member_permissions) { %i[view_members] }
      let(:members) { [member, non_member_role] }

      it_behaves_like 'consists of contract actions' do
        let(:expected) do
          [
            ['memberships/read', user.id, project.id]
          ]
        end
      end
    end

    context 'with a member with a permission and with the non member having the same permission' do
      let(:non_member_permissions) { %i[view_members] }
      let(:member_permissions) { %i[view_members] }
      let(:members) { [member, non_member_role] }

      it_behaves_like 'consists of contract actions' do
        let(:expected) do
          [
            ['memberships/read', user.id, project.id]
          ]
        end
      end
    end

    context 'with the non member role with an action permission and the user being locked' do
      let(:non_member_permissions) { %i[view_members] }
      let(:members) { [non_member_role] }

      before do
        project.update(public: true)
        user.locked!
      end

      it_behaves_like 'is empty'
    end

    context 'with an admin' do
      before do
        user.update(admin: true)
      end

      it_behaves_like 'consists of contract actions' do
        let(:expected) do
          # This complicated and programmatic way is chosen so that the test can deal with additional actions being defined
          item = ->(namespace, action, global, module_name) {
            # We only expect contract actions for project modules that are enabled by default. In the
            # default edition the Bim module is not enabled by default for instance and thus it's contract
            # actions are not expected to be part of the default capabilities.
            return if module_name.present? && project.enabled_module_names.exclude?(module_name.to_s)

            ["#{API::Utilities::PropertyNameConverter.from_ar_name(namespace.to_s.singularize).pluralize.underscore}/#{action}",
             user.id,
             global ? nil : project.id]
          }

          OpenProject::AccessControl
            .contract_actions_map
            .select { |_, v| v[:grant_to_admin] }
            .map { |_, v| v[:actions].map { |vk, vv| vv.map { |vvv| item.call(vk, vvv, v[:global], v[:module_name]) } } }
            .flatten(2)
            .compact
        end
      end
    end

    context 'with an admin but with modules deactivated' do
      before do
        user.update(admin: true)
        project.enabled_modules = []
      end

      it_behaves_like 'consists of contract actions' do
        let(:expected) do
          # This complicated and programmatic way is chosen so that the test can deal with additional actions being defined
          item = ->(namespace, action, global, module_name) {
            return if module_name.present?

            ["#{API::Utilities::PropertyNameConverter.from_ar_name(namespace.to_s.singularize).pluralize.underscore}/#{action}",
             user.id,
             global ? nil : project.id]
          }

          OpenProject::AccessControl
            .contract_actions_map
            .select { |_, v| v[:grant_to_admin] }
            .map { |_, v| v[:actions].map { |vk, vv| vv.map { |vvv| item.call(vk, vvv, v[:global], v[:module_name]) } } }
            .flatten(2)
            .compact
        end
      end
    end

    context 'with an admin but being locked' do
      before do
        user.update(admin: true)
        user.locked!
      end

      it_behaves_like 'is empty'
    end

    context 'without the current user being member in a project' do
      let(:permissions) { %i[manage_members] }
      let(:global_permissions) { %i[manage_user] }
      let(:members) { [member, global_member] }

      before do
        current_user.update(admin: false)
      end

      it_behaves_like 'is empty'
    end

    context 'with the current user being member in a project' do
      let(:permissions) { %i[manage_members] }
      let(:global_permissions) { %i[manage_user] }
      let(:members) { [own_member, member, global_member] }

      before do
        current_user.update(admin: false)
      end

      it_behaves_like 'consists of contract actions' do
        let(:expected) do
          [
            ['memberships/create', user.id, project.id],
            ['memberships/destroy', user.id, project.id],
            ['memberships/update', user.id, project.id],
            ['users/create', user.id, nil],
            ['users/read', user.id, nil],
            ['users/update', user.id, nil]
          ]
        end
      end
    end

    context 'with a member with an action permission that is not granted to admin' do
      let(:permissions) { %i[work_package_assigned] }
      let(:members) { [member] }

      it_behaves_like 'consists of contract actions' do
        let(:expected) do
          [
            ['work_packages/assigned', user.id, project.id]
          ]
        end
      end
    end

    context 'with a member with an action permission and the project being archived' do
      let(:permissions) { %i[manage_members] }
      let(:members) { [member] }

      before do
        project.update(active: false)
      end

      it_behaves_like 'is empty'
    end
  end
end
